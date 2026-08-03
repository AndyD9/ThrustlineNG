create table public.flight_dispatches (
    id uuid primary key default gen_random_uuid(),
    company_id uuid not null references public.companies (id) on delete cascade,
    aircraft_id uuid not null references public.company_aircraft (id) on delete cascade,
    departure_icao text not null,
    arrival_icao text not null,
    state text not null default 'draft',
    created_at timestamptz not null default clock_timestamp(),
    schema_version integer not null default 1,
    constraint flight_dispatches_departure_icao check (
        departure_icao ~ '^[A-Z0-9]{4}$'
    ),
    constraint flight_dispatches_arrival_icao check (
        arrival_icao ~ '^[A-Z0-9]{4}$'
    ),
    constraint flight_dispatches_distinct_airports check (
        departure_icao <> arrival_icao
    ),
    constraint flight_dispatches_draft_only check (state = 'draft'),
    constraint flight_dispatches_schema_version check (schema_version = 1),
    constraint flight_dispatches_one_draft_per_aircraft unique (aircraft_id)
);

create table private.dispatch_draft_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    idempotency_key uuid not null,
    company_id uuid not null references public.companies (id) on delete cascade,
    aircraft_id uuid not null references public.company_aircraft (id) on delete cascade,
    dispatch_id uuid not null references public.flight_dispatches (id) on delete cascade,
    departure_icao text not null,
    arrival_icao text not null,
    payload_sha256 text not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, idempotency_key),
    constraint dispatch_draft_commands_payload_hash check (
        payload_sha256 ~ '^[0-9a-f]{64}$'
    ),
    constraint dispatch_draft_commands_dispatch unique (dispatch_id),
    constraint dispatch_draft_commands_aircraft unique (aircraft_id)
);

alter table public.flight_dispatches enable row level security;
alter table public.flight_dispatches force row level security;
alter table private.dispatch_draft_commands enable row level security;
alter table private.dispatch_draft_commands force row level security;

revoke all on table public.flight_dispatches from public;
revoke all on table public.flight_dispatches from anon;
revoke all on table public.flight_dispatches from authenticated;
revoke all on table public.flight_dispatches from service_role;
grant select on table public.flight_dispatches to authenticated;

revoke all on table private.dispatch_draft_commands from public;
revoke all on table private.dispatch_draft_commands from anon;
revoke all on table private.dispatch_draft_commands from authenticated;
revoke all on table private.dispatch_draft_commands from service_role;

create policy flight_dispatches_select_own
on public.flight_dispatches
for select
to authenticated
using (
    exists (
        select 1
        from public.companies as companies
        where companies.id = flight_dispatches.company_id
          and companies.owner_id = (select auth.uid())
    )
);

comment on table public.flight_dispatches is
    'Server-created minimal dispatch drafts for company-owned aircraft; authenticated owners have read-only access.';
comment on table private.dispatch_draft_commands is
    'Private idempotency registry binding a normalized dispatch request to one server-created draft.';

create function public.create_dispatch_draft(
    owner_id uuid,
    idempotency_key uuid,
    aircraft_id uuid,
    departure_icao text,
    arrival_icao text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    company public.companies%rowtype;
    aircraft public.company_aircraft%rowtype;
    existing_command private.dispatch_draft_commands%rowtype;
    dispatch public.flight_dispatches%rowtype;
    normalized_departure text;
    normalized_arrival text;
    payload_hash text;
begin
    if owner_id is null or idempotency_key is null or aircraft_id is null
        or departure_icao is null or arrival_icao is null
    then
        raise invalid_parameter_value using
            message = 'Owner, idempotency key, aircraft, departure and arrival are required.';
    end if;

    normalized_departure := upper(btrim(departure_icao));
    normalized_arrival := upper(btrim(arrival_icao));

    if normalized_departure !~ '^[A-Z0-9]{4}$'
        or normalized_arrival !~ '^[A-Z0-9]{4}$'
        or normalized_departure = normalized_arrival
    then
        raise invalid_parameter_value using
            message = 'Departure and arrival must be distinct four-character ICAO codes.';
    end if;

    payload_hash := encode(
        extensions.digest(
            convert_to(
                jsonb_build_object(
                    'aircraftId', aircraft_id,
                    'arrivalIcao', normalized_arrival,
                    'departureIcao', normalized_departure
                )::text,
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    );

    select companies.*
    into company
    from public.companies as companies
    where companies.owner_id = create_dispatch_draft.owner_id
    for update;

    if not found or not private.account_is_active(create_dispatch_draft.owner_id) then
        raise object_not_in_prerequisite_state using
            message = 'Dispatch creation is unavailable.';
    end if;

    select commands.*
    into existing_command
    from private.dispatch_draft_commands as commands
    where commands.owner_id = create_dispatch_draft.owner_id
      and commands.idempotency_key = create_dispatch_draft.idempotency_key;

    if found then
        if existing_command.aircraft_id <> create_dispatch_draft.aircraft_id
            or existing_command.departure_icao <> normalized_departure
            or existing_command.arrival_icao <> normalized_arrival
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
            'arrivalIcao', dispatch.arrival_icao,
            'createdAt', dispatch.created_at,
            'departureIcao', dispatch.departure_icao,
            'dispatchId', dispatch.id,
            'schemaVersion', dispatch.schema_version,
            'state', dispatch.state
        );
    end if;

    select aircraft_rows.*
    into aircraft
    from public.company_aircraft as aircraft_rows
    where aircraft_rows.id = create_dispatch_draft.aircraft_id
      and aircraft_rows.company_id = company.id
    for update;

    if not found then
        raise object_not_in_prerequisite_state using
            message = 'Aircraft is unavailable for dispatch.';
    end if;

    if exists (
        select 1
        from public.flight_dispatches as dispatches
        where dispatches.aircraft_id = aircraft.id
    ) then
        raise object_not_in_prerequisite_state using
            message = 'Aircraft already has an active dispatch.';
    end if;

    insert into public.flight_dispatches (
        company_id,
        aircraft_id,
        departure_icao,
        arrival_icao
    )
    values (
        company.id,
        aircraft.id,
        normalized_departure,
        normalized_arrival
    )
    returning *
    into dispatch;

    insert into private.dispatch_draft_commands (
        owner_id,
        idempotency_key,
        company_id,
        aircraft_id,
        dispatch_id,
        departure_icao,
        arrival_icao,
        payload_sha256
    )
    values (
        create_dispatch_draft.owner_id,
        create_dispatch_draft.idempotency_key,
        company.id,
        aircraft.id,
        dispatch.id,
        normalized_departure,
        normalized_arrival,
        payload_hash
    );

    return jsonb_build_object(
        'aircraftId', dispatch.aircraft_id,
        'arrivalIcao', dispatch.arrival_icao,
        'createdAt', dispatch.created_at,
        'departureIcao', dispatch.departure_icao,
        'dispatchId', dispatch.id,
        'schemaVersion', dispatch.schema_version,
        'state', dispatch.state
    );
end;
$$;

revoke all on function public.create_dispatch_draft(uuid, uuid, uuid, text, text) from public;
revoke all on function public.create_dispatch_draft(uuid, uuid, uuid, text, text) from anon;
revoke all on function public.create_dispatch_draft(uuid, uuid, uuid, text, text) from authenticated;
grant execute on function public.create_dispatch_draft(uuid, uuid, uuid, text, text) to service_role;
