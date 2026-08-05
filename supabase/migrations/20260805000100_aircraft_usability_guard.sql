-- T0060 makes public.company_aircraft.is_usable opposable at the only two
-- entries that put an aircraft into service: the creation of a dispatch draft
-- and the start of a flight. T0032 already writes that column authoritatively --
-- it drops to false at expiry, at default, when a termination notice takes
-- effect and for the whole grace window, and it returns to true only when the
-- privileged temporal command clears every arrear. Until now no consumer read
-- it, so an aircraft whose lease had ended could still receive a fresh draft and
-- take off.
--
-- This migration adds no new source of unusability. The three lease commands
-- stay the only authority that writes is_usable; the two service-role commands
-- redefined below only read it, on the server-derived aircraft row, under lock.
-- public.close_flight is deliberately untouched: Andy decided on 4 August 2026
-- that a flight already under way stays closeable and settleable even after the
-- lease ends, so a terminal default can never strand an active dispatch.
--
-- Documented lock order, identical in both commands and compatible with the
-- lease commands: company, then dispatch, then aircraft. public.company_aircraft
-- is always the last row locked here, exactly as public.process_aircraft_lease
-- locks the contract and the financial subject before touching the aircraft, so
-- no (dispatch, lease) pair can build a lock cycle.

-- The whole living definition of create_dispatch_draft is rewritten in one
-- block, from the settlement file that owned it, because PostgreSQL has no way
-- to add a statement to an existing body. Every invariant it already carried is
-- carried over verbatim: T0047 ownership and idempotency registry, the T0057
-- bounded aerodrome reference, the deletion-pending block, the T0051 open-only
-- exclusivity and the seven-field versioned response. The usability guard is
-- evaluated before the exclusivity check on purpose: an unusable aircraft must
-- return the same opaque message whether or not it already has an open
-- dispatch, so the refusal never becomes a channel.
create or replace function public.create_dispatch_draft(
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
        or not exists (
            select 1
            from public.airports as airports
            where airports.icao_code = normalized_departure
        )
        or not exists (
            select 1
            from public.airports as airports
            where airports.icao_code = normalized_arrival
        )
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

    -- The usability guard. It reads nothing but is_usable, on the row the server
    -- derived and locked itself, and reuses the message already delivered by
    -- T0047 so that an aircraft out of contract stays indistinguishable from an
    -- unknown aircraft or one owned by another company. No detail and no hint
    -- names a lease, a state, a due date or a grace window.
    if not found or not aircraft.is_usable then
        raise object_not_in_prerequisite_state using
            message = 'Aircraft is unavailable for dispatch.';
    end if;

    if exists (
        select 1
        from public.flight_dispatches as dispatches
        where dispatches.aircraft_id = aircraft.id
          and dispatches.state in ('draft', 'active')
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

-- start_flight_from_dispatch never read the aircraft row at all: it locked the
-- company then the dispatch and moved draft to active without consulting
-- public.company_aircraft. It now derives that aircraft from the dispatch,
-- locks it last and refuses the transition when the aircraft is not usable.
-- Every T0050 control is preserved: deletion-pending block, server-derived
-- company and aircraft, the private.flight_start_commands registry with its
-- payload fingerprint, and the five-field response. The replay path is
-- untouched on purpose and returns before the guard: a start already acquired
-- while the aircraft was usable must keep returning exactly the stored
-- response, even after the lease ends. The guard applies to the fresh
-- transition only, never to the idempotency of a command already granted.
create or replace function public.start_flight_from_dispatch(
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
    aircraft public.company_aircraft%rowtype;
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

    -- Aircraft last in the documented lock order. The row is derived from the
    -- dispatch, never from a caller, and only is_usable is read. The refusal
    -- reuses the message already delivered by T0050, so an aircraft out of
    -- contract is indistinguishable from an unknown or foreign dispatch.
    select aircraft_rows.*
    into aircraft
    from public.company_aircraft as aircraft_rows
    where aircraft_rows.id = dispatch.aircraft_id
      and aircraft_rows.company_id = company.id
    for update;

    if not found or not aircraft.is_usable then
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

comment on column public.company_aircraft.is_usable is
    'Server-authoritative usability written only by the lease commands and read, under lock, by create_dispatch_draft and start_flight_from_dispatch before an aircraft enters service.';
