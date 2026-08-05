-- T0065 — Replay restitution for an already acquired flight start (KI-024).
--
-- Until this migration, the replay path of public.start_flight_from_dispatch
-- rebuilt its response from the living public.flight_dispatches row. As soon as
-- the flight was closed by public.close_flight, the state field therefore drifted:
-- a replay returned 'completed' instead of the 'active' granted at acquisition.
--
-- Measured on this stack, exactly one of the five fields drifts, not two. T0065
-- was opened expecting startedAt to be erased as well, because
-- private.set_flight_dispatch_started_at nulled it whenever the state left
-- 'active' in 20260803000200_authoritative_flight_start.sql. T0051 superseded that
-- trigger in 20260804000100_authoritative_flight_settlement.sql: a terminal state
-- now keeps `new.started_at := old.started_at`, and
-- flight_dispatches_started_at_matches_state requires it to be not null. The
-- 5 August 2026 pgTAP run proves the living read returns
-- ('completed', started_at not null, closed_at not null).
--
-- The fix does not lean on that. A replay reads no field a closure can move or
-- erase, so a future migration touching the trigger again cannot reopen KI-024.
--
-- Andy retained issue A on 5 August 2026: the guarantee is kept, not reduced. A
-- replay now returns exactly the response granted at acquisition, after a closure
-- included. No new column is stored: private.flight_start_commands already keeps
-- aircraft_id, dispatch_id and a not-null started_at, its row is written only
-- inside the transaction that succeeded in moving the dispatch from 'draft' to
-- 'active' — so state was necessarily 'active' at that instant — and
-- schema_version is immutable, hence still read from the dispatch row.
--
-- This is the third wholesale redefinition of this command, so LC-2026-002
-- applies: every T0050 invariant and the T0060 usability guard are restated here,
-- against this file, and the backend gate reaffirms them against it. Nothing else
-- changes. public.create_dispatch_draft is deliberately not redefined: this
-- migration does not touch it, and its living definition stays in
-- 20260805000100_aircraft_usability_guard.sql.
--
-- Documented lock order is unchanged: company, then dispatch, then aircraft.

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
    acquired_schema_version public.flight_dispatches.schema_version%type;
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

        -- Replay restitution T0065. The three fields a closure can move or erase
        -- come from the registry written inside the granting transaction, and
        -- never from the living dispatch row: aircraftId and startedAt are stored
        -- columns, and state is the literal 'active' because the registry row
        -- exists only after that transition succeeded. Only the immutable
        -- schema_version is still read from the dispatch, and no state, started_at
        -- or closed_at is read from it. A replay therefore creates no second
        -- start, no second registry row and no financial effect, and it returns
        -- before the usability guard below: a start already acquired keeps its
        -- exact response even after the aircraft leaves service.
        select dispatches.schema_version
        into strict acquired_schema_version
        from public.flight_dispatches as dispatches
        where dispatches.id = existing_command.dispatch_id;

        return jsonb_build_object(
            'aircraftId', existing_command.aircraft_id,
            'dispatchId', existing_command.dispatch_id,
            'schemaVersion', acquired_schema_version,
            'startedAt', existing_command.started_at,
            'state', 'active'
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

comment on table private.flight_start_commands is
    'Idempotency registry of granted flight starts. Its stored aircraft_id and started_at are the authority a replay restitutes, so the response of an acquired start never depends on the living dispatch row.';
