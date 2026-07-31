create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

create table private.account_deletion_requests (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users (id) on delete restrict,
    company_id uuid not null references public.companies (id) on delete restrict,
    request_key uuid not null,
    export_payload jsonb,
    export_sha256 text,
    requested_at timestamptz not null,
    delete_after timestamptz not null,
    cancelled_at timestamptz,
    constraint account_deletion_requests_owner_key unique (owner_id, request_key),
    constraint account_deletion_requests_window check (
        delete_after = requested_at + interval '7 days'
    ),
    constraint account_deletion_requests_export_pair check (
        (export_payload is null) = (export_sha256 is null)
    ),
    constraint account_deletion_requests_state check (
        (cancelled_at is null and export_payload is not null)
        or
        (cancelled_at is not null and export_payload is null)
    )
);

create unique index account_deletion_requests_one_pending_per_owner
on private.account_deletion_requests (owner_id)
where cancelled_at is null;

create table private.account_lifecycle_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    operation text not null,
    idempotency_key uuid not null,
    response jsonb not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, operation, idempotency_key),
    constraint account_lifecycle_commands_operation check (
        operation in ('request_deletion', 'cancel_deletion')
    )
);

create table private.account_deletion_markers (
    request_token_hash text primary key,
    marker_id uuid not null unique,
    completed_at timestamptz not null,
    export_schema_version integer not null,
    constraint account_deletion_markers_hash_format check (
        request_token_hash ~ '^[0-9a-f]{64}$'
    ),
    constraint account_deletion_markers_export_version check (
        export_schema_version = 1
    )
);

alter table private.account_deletion_requests enable row level security;
alter table private.account_deletion_requests force row level security;
alter table private.account_lifecycle_commands enable row level security;
alter table private.account_lifecycle_commands force row level security;
alter table private.account_deletion_markers enable row level security;
alter table private.account_deletion_markers force row level security;

revoke all on all tables in schema private from public;
revoke all on all tables in schema private from anon;
revoke all on all tables in schema private from authenticated;

comment on table private.account_deletion_requests is
    'Recoverable seven-day account deletion requests and portable export snapshots.';
comment on table private.account_lifecycle_commands is
    'Temporary idempotency records removed when their Auth owner is deleted.';
comment on table private.account_deletion_markers is
    'Non-personal completion markers keyed only by a random request token hash.';

create function private.current_reauthenticated_user()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    claims jsonb := auth.jwt();
    actor_id uuid := auth.uid();
    session_id uuid;
    cutoff timestamptz := clock_timestamp() - interval '5 minutes';
    has_recent_method boolean;
begin
    if actor_id is null
        or coalesce(claims ->> 'role', '') <> 'authenticated'
        or coalesce((claims ->> 'is_anonymous')::boolean, false)
    then
        raise insufficient_privilege using
            message = 'Recent reauthentication is required.';
    end if;

    begin
        session_id := nullif(claims ->> 'session_id', '')::uuid;
    exception
        when invalid_text_representation then
            raise insufficient_privilege using
                message = 'Recent reauthentication is required.';
    end;

    if session_id is null or not exists (
        select 1
        from auth.sessions as sessions
        where sessions.id = session_id
          and sessions.user_id = actor_id
          and sessions.created_at >= cutoff
          and (sessions.not_after is null or sessions.not_after > clock_timestamp())
    ) then
        raise insufficient_privilege using
            message = 'Recent reauthentication is required.';
    end if;

    select exists (
        select 1
        from jsonb_array_elements(coalesce(claims -> 'amr', '[]'::jsonb)) as method
        where method ->> 'method' in (
            'password',
            'otp',
            'totp',
            'oauth',
            'sso/saml',
            'magiclink'
        )
          and method ->> 'timestamp' ~ '^[0-9]+([.][0-9]+)?$'
          and to_timestamp((method ->> 'timestamp')::double precision) >= cutoff
    )
    into has_recent_method;

    if not has_recent_method then
        raise insufficient_privilege using
            message = 'Recent reauthentication is required.';
    end if;

    return actor_id;
end;
$$;

create function private.account_is_active(target_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select not exists (
        select 1
        from private.account_deletion_requests as requests
        where requests.owner_id = target_owner_id
          and requests.cancelled_at is null
    );
$$;

revoke all on function private.current_reauthenticated_user() from public;
revoke all on function private.current_reauthenticated_user() from anon;
revoke all on function private.current_reauthenticated_user() from authenticated;
revoke all on function private.account_is_active(uuid) from public;
revoke all on function private.account_is_active(uuid) from anon;
revoke all on function private.account_is_active(uuid) from authenticated;
grant execute on function private.account_is_active(uuid) to authenticated;

drop policy companies_insert_own on public.companies;
drop policy companies_update_own on public.companies;
drop policy companies_delete_own on public.companies;

create policy companies_insert_own
on public.companies
for insert
to authenticated
with check (
    (select auth.uid()) = owner_id
    and private.account_is_active(owner_id)
);

create policy companies_update_own
on public.companies
for update
to authenticated
using (
    (select auth.uid()) = owner_id
    and private.account_is_active(owner_id)
)
with check (
    (select auth.uid()) = owner_id
    and private.account_is_active(owner_id)
);

create policy companies_delete_own
on public.companies
for delete
to authenticated
using (
    (select auth.uid()) = owner_id
    and private.account_is_active(owner_id)
);

create function public.request_account_deletion(idempotency_key uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    actor_id uuid := private.current_reauthenticated_user();
    company public.companies%rowtype;
    existing_response jsonb;
    pending_request private.account_deletion_requests%rowtype;
    generated_at timestamptz := clock_timestamp();
    portable_export jsonb;
    export_hash text;
    response jsonb;
begin
    if idempotency_key is null then
        raise invalid_parameter_value using
            message = 'An idempotency key is required.';
    end if;

    perform 1
    from auth.users
    where id = actor_id
    for update;

    if not found then
        raise insufficient_privilege using
            message = 'Account lifecycle operation is not permitted.';
    end if;

    select commands.response
    into existing_response
    from private.account_lifecycle_commands as commands
    where commands.owner_id = actor_id
      and commands.operation = 'request_deletion'
      and commands.idempotency_key = request_account_deletion.idempotency_key;

    if existing_response is not null then
        if existing_response ->> 'state' = 'deletion_pending'
            and exists (
                select 1
                from private.account_deletion_requests as requests
                where requests.id = (existing_response ->> 'requestId')::uuid
                  and requests.owner_id = actor_id
                  and requests.cancelled_at is null
                  and requests.delete_after <= clock_timestamp()
            )
        then
            raise object_not_in_prerequisite_state using
                message = 'Account deletion is awaiting server finalization.';
        end if;
        return existing_response;
    end if;

    select requests.*
    into pending_request
    from private.account_deletion_requests as requests
    where requests.owner_id = actor_id
      and requests.cancelled_at is null
    for update;

    if found then
        if pending_request.delete_after <= clock_timestamp() then
            raise object_not_in_prerequisite_state using
                message = 'Account deletion is awaiting server finalization.';
        end if;

        response := jsonb_build_object(
            'requestId', pending_request.id,
            'state', 'deletion_pending',
            'requestedAt', pending_request.requested_at,
            'deleteAfter', pending_request.delete_after,
            'exportSha256', pending_request.export_sha256,
            'export', pending_request.export_payload
        );

        insert into private.account_lifecycle_commands (
            owner_id,
            operation,
            idempotency_key,
            response
        )
        values (
            actor_id,
            'request_deletion',
            request_account_deletion.idempotency_key,
            response
        );

        return response;
    end if;

    select companies.*
    into strict company
    from public.companies as companies
    where companies.owner_id = actor_id
    for update;

    portable_export := jsonb_build_object(
        'format', 'thrustline-account-export',
        'schemaVersion', 1,
        'generatedAt', generated_at,
        'account', jsonb_build_object(
            'email', (
                select users.email
                from auth.users as users
                where users.id = actor_id
            )
        ),
        'company', jsonb_build_object(
            'id', company.id,
            'name', company.name,
            'createdAt', company.created_at,
            'updatedAt', company.updated_at
        )
    );
    export_hash := encode(
        extensions.digest(convert_to(portable_export::text, 'UTF8'), 'sha256'),
        'hex'
    );

    insert into private.account_deletion_requests (
        owner_id,
        company_id,
        request_key,
        export_payload,
        export_sha256,
        requested_at,
        delete_after
    )
    values (
        actor_id,
        company.id,
        idempotency_key,
        portable_export,
        export_hash,
        generated_at,
        generated_at + interval '7 days'
    )
    returning *
    into pending_request;

    response := jsonb_build_object(
        'requestId', pending_request.id,
        'state', 'deletion_pending',
        'requestedAt', pending_request.requested_at,
        'deleteAfter', pending_request.delete_after,
        'exportSha256', pending_request.export_sha256,
        'export', pending_request.export_payload
    );

    insert into private.account_lifecycle_commands (
        owner_id,
        operation,
        idempotency_key,
        response
    )
    values (
        actor_id,
        'request_deletion',
        idempotency_key,
        response
    );

    return response;
exception
    when no_data_found then
        raise insufficient_privilege using
            message = 'Account lifecycle operation is not permitted.';
end;
$$;

create function public.get_account_export(request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    actor_id uuid := private.current_reauthenticated_user();
    response jsonb;
begin
    select jsonb_build_object(
        'requestId', requests.id,
        'state', 'deletion_pending',
        'requestedAt', requests.requested_at,
        'deleteAfter', requests.delete_after,
        'exportSha256', requests.export_sha256,
        'export', requests.export_payload
    )
    into response
    from private.account_deletion_requests as requests
    where requests.id = get_account_export.request_id
      and requests.owner_id = actor_id
      and requests.cancelled_at is null
      and requests.delete_after > clock_timestamp();

    if response is null then
        raise insufficient_privilege using
            message = 'Account lifecycle operation is not permitted.';
    end if;

    return response;
end;
$$;

create function public.cancel_account_deletion(
    request_id uuid,
    idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    actor_id uuid := private.current_reauthenticated_user();
    existing_response jsonb;
    request private.account_deletion_requests%rowtype;
    response jsonb;
begin
    if idempotency_key is null then
        raise invalid_parameter_value using
            message = 'An idempotency key is required.';
    end if;

    perform 1
    from auth.users
    where id = actor_id
    for update;

    select commands.response
    into existing_response
    from private.account_lifecycle_commands as commands
    where commands.owner_id = actor_id
      and commands.operation = 'cancel_deletion'
      and commands.idempotency_key = cancel_account_deletion.idempotency_key;

    if existing_response is not null then
        if existing_response ->> 'requestId'
            <> cancel_account_deletion.request_id::text
        then
            raise invalid_parameter_value using
                message = 'Idempotency key was already used for another request.';
        end if;
        return existing_response;
    end if;

    select requests.*
    into request
    from private.account_deletion_requests as requests
    where requests.id = cancel_account_deletion.request_id
      and requests.owner_id = actor_id
    for update;

    if not found or request.delete_after <= clock_timestamp() then
        raise insufficient_privilege using
            message = 'Account lifecycle operation is not permitted.';
    end if;

    if request.cancelled_at is null then
        update private.account_deletion_requests as requests
        set cancelled_at = clock_timestamp(),
            export_payload = null,
            export_sha256 = null
        where requests.id = request.id
        returning requests.*
        into request;
    end if;

    response := jsonb_build_object(
        'requestId', request.id,
        'state', 'active',
        'cancelledAt', request.cancelled_at
    );

    update private.account_lifecycle_commands as commands
    set response = jsonb_build_object(
        'requestId', request.id,
        'state', 'active',
        'cancelledAt', request.cancelled_at
    )
    where commands.owner_id = actor_id
      and commands.operation = 'request_deletion';

    insert into private.account_lifecycle_commands (
        owner_id,
        operation,
        idempotency_key,
        response
    )
    values (
        actor_id,
        'cancel_deletion',
        cancel_account_deletion.idempotency_key,
        response
    );

    return response;
end;
$$;

create function public.finalize_account_deletion(request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    request private.account_deletion_requests%rowtype;
    request_hash text := encode(
        extensions.digest(convert_to(request_id::text, 'UTF8'), 'sha256'),
        'hex'
    );
    marker private.account_deletion_markers%rowtype;
begin
    select markers.*
    into marker
    from private.account_deletion_markers as markers
    where markers.request_token_hash = request_hash;

    if found then
        return jsonb_build_object(
            'markerId', marker.marker_id,
            'state', 'deleted',
            'completedAt', marker.completed_at,
            'exportSchemaVersion', marker.export_schema_version
        );
    end if;

    select requests.*
    into request
    from private.account_deletion_requests as requests
    where requests.id = finalize_account_deletion.request_id
      and requests.cancelled_at is null
    for update;

    if not found or request.delete_after > clock_timestamp() then
        raise object_not_in_prerequisite_state using
            message = 'Account deletion is not ready for finalization.';
    end if;

    insert into private.account_deletion_markers (
        request_token_hash,
        marker_id,
        completed_at,
        export_schema_version
    )
    values (
        request_hash,
        gen_random_uuid(),
        clock_timestamp(),
        1
    )
    returning *
    into marker;

    delete from private.account_lifecycle_commands
    where owner_id = request.owner_id;

    delete from private.account_deletion_requests
    where owner_id = request.owner_id;

    delete from public.companies
    where id = request.company_id
      and owner_id = request.owner_id;

    if not found then
        raise integrity_constraint_violation using
            message = 'Account company is missing during finalization.';
    end if;

    delete from auth.users
    where id = request.owner_id;

    if not found then
        raise integrity_constraint_violation using
            message = 'Auth owner is missing during finalization.';
    end if;

    return jsonb_build_object(
        'markerId', marker.marker_id,
        'state', 'deleted',
        'completedAt', marker.completed_at,
        'exportSchemaVersion', marker.export_schema_version
    );
end;
$$;

revoke all on function public.request_account_deletion(uuid) from public;
revoke all on function public.get_account_export(uuid) from public;
revoke all on function public.cancel_account_deletion(uuid, uuid) from public;
revoke all on function public.finalize_account_deletion(uuid) from public;

revoke all on function public.request_account_deletion(uuid) from anon;
revoke all on function public.get_account_export(uuid) from anon;
revoke all on function public.cancel_account_deletion(uuid, uuid) from anon;
revoke all on function public.finalize_account_deletion(uuid) from anon;

revoke all on function public.finalize_account_deletion(uuid) from authenticated;

grant execute on function public.request_account_deletion(uuid) to authenticated;
grant execute on function public.get_account_export(uuid) to authenticated;
grant execute on function public.cancel_account_deletion(uuid, uuid) to authenticated;
grant execute on function public.finalize_account_deletion(uuid) to service_role;

comment on function public.request_account_deletion(uuid) is
    'Creates or replays a seven-day deletion request after recent server-verified reauthentication.';
comment on function public.get_account_export(uuid) is
    'Returns the caller-owned portable export during the recoverable window.';
comment on function public.cancel_account_deletion(uuid, uuid) is
    'Idempotently cancels a caller-owned deletion request after recent reauthentication.';
comment on function public.finalize_account_deletion(uuid) is
    'Service-role-only transactional account finalization after the recovery deadline.';
