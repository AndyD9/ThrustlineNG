create table private.account_restoration_subjects (
    subject_token uuid primary key default gen_random_uuid(),
    owner_id uuid not null unique references auth.users (id) on delete cascade,
    company_id uuid not null unique references public.companies (id) on delete cascade,
    created_at timestamptz not null default clock_timestamp()
);

create table private.account_deletion_replay_events (
    subject_token uuid primary key,
    request_token_hash text not null unique,
    marker_id uuid not null unique,
    completed_at timestamptz not null,
    export_schema_version integer not null,
    event_schema_version integer not null,
    constraint account_deletion_replay_events_request_hash_format check (
        request_token_hash ~ '^[0-9a-f]{64}$'
    ),
    constraint account_deletion_replay_events_export_version check (
        export_schema_version = 1
    ),
    constraint account_deletion_replay_events_event_version check (
        event_schema_version = 1
    )
);

alter table private.account_restoration_subjects enable row level security;
alter table private.account_restoration_subjects force row level security;
alter table private.account_deletion_replay_events enable row level security;
alter table private.account_deletion_replay_events force row level security;

revoke all on private.account_restoration_subjects from public;
revoke all on private.account_restoration_subjects from anon;
revoke all on private.account_restoration_subjects from authenticated;
revoke all on private.account_deletion_replay_events from public;
revoke all on private.account_deletion_replay_events from anon;
revoke all on private.account_deletion_replay_events from authenticated;

comment on table private.account_restoration_subjects is
    'Private pre-backup mapping from an opaque restore token to the active account.';
comment on table private.account_deletion_replay_events is
    'Pseudonymous versioned deletion events exported after a backup and replayed before reopen.';

create function private.create_account_restoration_subject()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into private.account_restoration_subjects (
        owner_id,
        company_id
    )
    values (
        new.owner_id,
        new.id
    )
    on conflict (owner_id) do nothing;

    return new;
end;
$$;

revoke all on function private.create_account_restoration_subject() from public;
revoke all on function private.create_account_restoration_subject() from anon;
revoke all on function private.create_account_restoration_subject() from authenticated;

create trigger companies_create_restoration_subject
after insert on public.companies
for each row
execute function private.create_account_restoration_subject();

insert into private.account_restoration_subjects (
    owner_id,
    company_id
)
select
    companies.owner_id,
    companies.id
from public.companies as companies
on conflict (owner_id) do nothing;

create or replace function public.finalize_account_deletion(request_id uuid)
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
    restoration_subject private.account_restoration_subjects%rowtype;
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

    select subjects.*
    into restoration_subject
    from private.account_restoration_subjects as subjects
    where subjects.owner_id = request.owner_id
      and subjects.company_id = request.company_id
    for update;

    if not found then
        raise integrity_constraint_violation using
            message = 'Account restoration subject is missing during finalization.';
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

    insert into private.account_deletion_replay_events (
        subject_token,
        request_token_hash,
        marker_id,
        completed_at,
        export_schema_version,
        event_schema_version
    )
    values (
        restoration_subject.subject_token,
        marker.request_token_hash,
        marker.marker_id,
        marker.completed_at,
        marker.export_schema_version,
        1
    );

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

create function public.replay_account_deletion_event(
    subject_token uuid,
    request_token_hash text,
    marker_id uuid,
    completed_at timestamptz,
    export_schema_version integer,
    event_schema_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    existing_event private.account_deletion_replay_events%rowtype;
    restoration_subject private.account_restoration_subjects%rowtype;
    restored_request private.account_deletion_requests%rowtype;
begin
    if replay_account_deletion_event.subject_token is null
        or replay_account_deletion_event.request_token_hash
            !~ '^[0-9a-f]{64}$'
        or replay_account_deletion_event.marker_id is null
        or replay_account_deletion_event.completed_at is null
        or replay_account_deletion_event.completed_at > clock_timestamp()
        or replay_account_deletion_event.export_schema_version <> 1
        or replay_account_deletion_event.event_schema_version <> 1
    then
        raise invalid_parameter_value using
            message = 'Deletion replay event is invalid.';
    end if;

    select events.*
    into existing_event
    from private.account_deletion_replay_events as events
    where events.subject_token = replay_account_deletion_event.subject_token
    for update;

    if found then
        if existing_event.request_token_hash
                <> replay_account_deletion_event.request_token_hash
            or existing_event.marker_id
                <> replay_account_deletion_event.marker_id
            or existing_event.completed_at
                <> replay_account_deletion_event.completed_at
            or existing_event.export_schema_version
                <> replay_account_deletion_event.export_schema_version
            or existing_event.event_schema_version
                <> replay_account_deletion_event.event_schema_version
        then
            raise invalid_parameter_value using
                message = 'Deletion replay event conflicts with the recorded event.';
        end if;

        return jsonb_build_object(
            'markerId', existing_event.marker_id,
            'state', 'deleted',
            'completedAt', existing_event.completed_at,
            'eventSchemaVersion', existing_event.event_schema_version
        );
    end if;

    select subjects.*
    into restoration_subject
    from private.account_restoration_subjects as subjects
    where subjects.subject_token = replay_account_deletion_event.subject_token
    for update;

    if not found then
        raise object_not_in_prerequisite_state using
            message = 'Deletion replay event does not match the restored backup.';
    end if;

    select requests.*
    into restored_request
    from private.account_deletion_requests as requests
    where requests.owner_id = restoration_subject.owner_id
      and requests.cancelled_at is null
    for update;

    if found and encode(
        extensions.digest(
            convert_to(restored_request.id::text, 'UTF8'),
            'sha256'
        ),
        'hex'
    ) <> replay_account_deletion_event.request_token_hash
    then
        raise invalid_parameter_value using
            message = 'Deletion replay event conflicts with the restored request.';
    end if;

    insert into private.account_deletion_markers (
        request_token_hash,
        marker_id,
        completed_at,
        export_schema_version
    )
    values (
        replay_account_deletion_event.request_token_hash,
        replay_account_deletion_event.marker_id,
        replay_account_deletion_event.completed_at,
        replay_account_deletion_event.export_schema_version
    );

    insert into private.account_deletion_replay_events (
        subject_token,
        request_token_hash,
        marker_id,
        completed_at,
        export_schema_version,
        event_schema_version
    )
    values (
        replay_account_deletion_event.subject_token,
        replay_account_deletion_event.request_token_hash,
        replay_account_deletion_event.marker_id,
        replay_account_deletion_event.completed_at,
        replay_account_deletion_event.export_schema_version,
        replay_account_deletion_event.event_schema_version
    );

    delete from private.account_lifecycle_commands
    where owner_id = restoration_subject.owner_id;

    delete from private.account_deletion_requests
    where owner_id = restoration_subject.owner_id;

    delete from public.companies
    where id = restoration_subject.company_id
      and owner_id = restoration_subject.owner_id;

    if not found then
        raise integrity_constraint_violation using
            message = 'Restored company is missing during deletion replay.';
    end if;

    delete from auth.users
    where id = restoration_subject.owner_id;

    if not found then
        raise integrity_constraint_violation using
            message = 'Restored Auth owner is missing during deletion replay.';
    end if;

    return jsonb_build_object(
        'markerId', replay_account_deletion_event.marker_id,
        'state', 'deleted',
        'completedAt', replay_account_deletion_event.completed_at,
        'eventSchemaVersion', replay_account_deletion_event.event_schema_version
    );
end;
$$;

revoke all on function public.replay_account_deletion_event(
    uuid,
    text,
    uuid,
    timestamptz,
    integer,
    integer
) from public;
revoke all on function public.replay_account_deletion_event(
    uuid,
    text,
    uuid,
    timestamptz,
    integer,
    integer
) from anon;
revoke all on function public.replay_account_deletion_event(
    uuid,
    text,
    uuid,
    timestamptz,
    integer,
    integer
) from authenticated;
grant execute on function public.replay_account_deletion_event(
    uuid,
    text,
    uuid,
    timestamptz,
    integer,
    integer
) to service_role;

comment on function public.replay_account_deletion_event(
    uuid,
    text,
    uuid,
    timestamptz,
    integer,
    integer
) is
    'Replays one versioned deletion event into an isolated restored database before reopen.';
