alter table public.flight_dispatches
    drop constraint flight_dispatches_draft_only;

alter table public.flight_dispatches
    add constraint flight_dispatches_known_states check (state in ('draft', 'active'));

alter table public.flight_dispatches
    add column started_at timestamptz;

alter table public.flight_dispatches
    add constraint flight_dispatches_started_at_matches_state check (
        (state = 'draft' and started_at is null)
        or (state = 'active' and started_at is not null)
    );

comment on constraint flight_dispatches_one_draft_per_aircraft on public.flight_dispatches is
    'Exactly one dispatch per aircraft across every known state: the draft created by T0047 and the flight started by T0050 remain the same exclusive row.';
comment on column public.flight_dispatches.started_at is
    'Server-derived departure timestamp, written only while a draft becomes active and never accepted from a caller.';

create function private.set_flight_dispatch_started_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.state = 'active' then
        if tg_op = 'INSERT' or old.state <> 'active' then
            new.started_at := clock_timestamp();
        else
            new.started_at := old.started_at;
        end if;
    else
        new.started_at := null;
    end if;

    return new;
end;
$$;

create trigger flight_dispatches_server_started_at
before insert or update on public.flight_dispatches
for each row execute function private.set_flight_dispatch_started_at();

create table private.flight_start_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    idempotency_key uuid not null,
    company_id uuid not null references public.companies (id) on delete cascade,
    aircraft_id uuid not null references public.company_aircraft (id) on delete cascade,
    dispatch_id uuid not null references public.flight_dispatches (id) on delete cascade,
    payload_sha256 text not null,
    started_at timestamptz not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, idempotency_key),
    constraint flight_start_commands_payload_hash check (
        payload_sha256 ~ '^[0-9a-f]{64}$'
    ),
    constraint flight_start_commands_dispatch unique (dispatch_id)
);

alter table private.flight_start_commands enable row level security;
alter table private.flight_start_commands force row level security;

revoke all on table private.flight_start_commands from public;
revoke all on table private.flight_start_commands from anon;
revoke all on table private.flight_start_commands from authenticated;
revoke all on table private.flight_start_commands from service_role;

comment on table private.flight_start_commands is
    'Private idempotency registry binding one owner request to the single flight started from a dispatch.';

create function public.start_flight_from_dispatch(
    owner_id uuid,
    idempotency_key uuid,
    dispatch_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    company public.companies%rowtype;
    dispatch public.flight_dispatches%rowtype;
    existing_command private.flight_start_commands%rowtype;
    payload_hash text;
begin
    if owner_id is null or idempotency_key is null or dispatch_id is null then
        raise invalid_parameter_value using
            message = 'Owner, idempotency key and dispatch are required.';
    end if;

    payload_hash := encode(
        extensions.digest(
            convert_to(
                jsonb_build_object('dispatchId', dispatch_id)::text,
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    );

    select companies.*
    into company
    from public.companies as companies
    where companies.owner_id = start_flight_from_dispatch.owner_id
    for update;

    if not found or not private.account_is_active(start_flight_from_dispatch.owner_id) then
        raise object_not_in_prerequisite_state using
            message = 'Flight start is unavailable.';
    end if;

    select commands.*
    into existing_command
    from private.flight_start_commands as commands
    where commands.owner_id = start_flight_from_dispatch.owner_id
      and commands.idempotency_key = start_flight_from_dispatch.idempotency_key;

    if found then
        if existing_command.dispatch_id <> start_flight_from_dispatch.dispatch_id
            or existing_command.payload_sha256 <> payload_hash
        then
            raise invalid_parameter_value using
                message = 'Idempotency key was already used with a different payload.';
        end if;

        select dispatches.*
        into strict dispatch
        from public.flight_dispatches as dispatches
        where dispatches.id = existing_command.dispatch_id;

        return jsonb_build_object(
            'aircraftId', dispatch.aircraft_id,
            'dispatchId', dispatch.id,
            'schemaVersion', dispatch.schema_version,
            'startedAt', dispatch.started_at,
            'state', dispatch.state
        );
    end if;

    select dispatches.*
    into dispatch
    from public.flight_dispatches as dispatches
    where dispatches.id = start_flight_from_dispatch.dispatch_id
      and dispatches.company_id = company.id
    for update;

    if not found or dispatch.state <> 'draft' then
        raise object_not_in_prerequisite_state using
            message = 'Dispatch is unavailable for flight start.';
    end if;

    update public.flight_dispatches as dispatches
    set state = 'active'
    where dispatches.id = dispatch.id
    returning *
    into dispatch;

    insert into private.flight_start_commands (
        owner_id,
        idempotency_key,
        company_id,
        aircraft_id,
        dispatch_id,
        payload_sha256,
        started_at
    )
    values (
        start_flight_from_dispatch.owner_id,
        start_flight_from_dispatch.idempotency_key,
        company.id,
        dispatch.aircraft_id,
        dispatch.id,
        payload_hash,
        dispatch.started_at
    );

    return jsonb_build_object(
        'aircraftId', dispatch.aircraft_id,
        'dispatchId', dispatch.id,
        'schemaVersion', dispatch.schema_version,
        'startedAt', dispatch.started_at,
        'state', dispatch.state
    );
end;
$$;

revoke all on function public.start_flight_from_dispatch(uuid, uuid, uuid) from public;
revoke all on function public.start_flight_from_dispatch(uuid, uuid, uuid) from anon;
revoke all on function public.start_flight_from_dispatch(uuid, uuid, uuid) from authenticated;
grant execute on function public.start_flight_from_dispatch(uuid, uuid, uuid) to service_role;
