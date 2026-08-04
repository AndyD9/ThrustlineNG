-- T0051 closes a flight exactly once, settles a single net ledger entry and
-- records an informative reputation delta. Nothing delivered before is
-- rewritten: the ledger keeps its append-only triggers, T0047 keeps its public
-- dispatch contract and T0050 keeps its server-derived departure timestamp.

-- The ledger gains one more known entry type, exactly as T0029 did for the
-- aircraft purchase. A settlement is always a credit, so its sign is
-- constrained instead of being trusted from a caller.
alter table private.financial_ledger_entries
    drop constraint financial_ledger_entries_known_type;

alter table private.financial_ledger_entries
    add constraint financial_ledger_entries_known_type
        check (entry_type in ('opening_balance', 'aircraft_purchase', 'flight_settlement')),
    add constraint financial_ledger_entries_settlement_positive
        check (entry_type <> 'flight_settlement' or amount_minor > 0);

-- Two terminal states join the closed list opened by T0050. A terminal state
-- keeps the departure timestamp it was given and gains a server closing time.
alter table public.flight_dispatches
    drop constraint flight_dispatches_known_states,
    drop constraint flight_dispatches_started_at_matches_state;

alter table public.flight_dispatches
    add column closed_at timestamptz;

alter table public.flight_dispatches
    add constraint flight_dispatches_known_states
        check (state in ('draft', 'active', 'completed', 'interrupted')),
    add constraint flight_dispatches_started_at_matches_state check (
        (state = 'draft' and started_at is null)
        or (state in ('active', 'completed', 'interrupted') and started_at is not null)
    ),
    add constraint flight_dispatches_closed_at_matches_state check (
        (state in ('draft', 'active') and closed_at is null)
        or (state in ('completed', 'interrupted') and closed_at is not null)
    ),
    add constraint flight_dispatches_closed_after_start check (
        closed_at is null or closed_at >= started_at
    );

-- Exclusivity per aircraft becomes partial: it still admits exactly one open
-- dispatch per aircraft, and a closed flight stays in place as history while the
-- aircraft becomes immediately dispatchable again.
alter table public.flight_dispatches
    drop constraint flight_dispatches_one_draft_per_aircraft;

create unique index flight_dispatches_one_open_per_aircraft
    on public.flight_dispatches (aircraft_id)
    where state in ('draft', 'active');

-- The private draft registry carried the same global exclusivity. The dispatch
-- table is now the single authority for it, so the registry keeps only its
-- idempotency guarantees: one command per owner and key, one command per
-- dispatch.
alter table private.dispatch_draft_commands
    drop constraint dispatch_draft_commands_aircraft;

comment on index public.flight_dispatches_one_open_per_aircraft is
    'One open dispatch per aircraft across draft and active only: a completed or interrupted flight is history and never blocks a new dispatch.';
comment on column public.flight_dispatches.closed_at is
    'Server-derived closing timestamp, written only while a flight reaches a terminal state and never accepted from a caller.';

create or replace function private.set_flight_dispatch_started_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.state = 'draft' then
        new.started_at := null;
        new.closed_at := null;
    elsif new.state = 'active' then
        if tg_op = 'INSERT' or old.state <> 'active' then
            new.started_at := clock_timestamp();
        else
            new.started_at := old.started_at;
        end if;

        new.closed_at := null;
    else
        if tg_op = 'INSERT' then
            raise object_not_in_prerequisite_state using
                message = 'A dispatch cannot be created in a terminal state.';
        end if;

        new.started_at := old.started_at;

        if old.state in ('completed', 'interrupted') then
            new.closed_at := old.closed_at;
        else
            new.closed_at := clock_timestamp();
        end if;
    end if;

    return new;
end;
$$;

-- Canonical projection of eng/flight-settlement-policy.json. The backend gate
-- rebuilds this block from the canonical source and fails on any divergence, so
-- no monetary value can drift between the two, and none is ever read from an
-- environment variable.
create function private.flight_settlement_policy()
returns jsonb
language sql
immutable
set search_path = ''
as $$
    select jsonb_build_object(
        'schemaVersion', 1,
        'currencyCode', 'EUR',
        'baseAmountMinor', 15000,
        'perNauticalMileMinor', 120,
        'perBlockMinuteMinor', 300,
        'interruptedFloorMinor', 5000,
        'perFlightCapMinor', 2000000,
        'maximumBlockMinutes', 1440,
        'multiplierRegional', 0.9,
        'multiplierStandard', 1.0,
        'multiplierMajor', 1.15,
        'multiplierHub', 1.3,
        'reputationBaseScore', 50,
        'reputationMinimumScore', 0,
        'reputationMaximumScore', 100,
        'reputationCompletedDelta', 1,
        'reputationInterruptedDelta', -3
    );
$$;

revoke all on function private.flight_settlement_policy() from public;
revoke all on function private.flight_settlement_policy() from anon;
revoke all on function private.flight_settlement_policy() from authenticated;
revoke all on function private.flight_settlement_policy() from service_role;

comment on function private.flight_settlement_policy() is
    'Embedded projection of eng/flight-settlement-policy.json, the canonical source of the alpha settlement scale and of the informative reputation deltas.';

-- Great-circle distance in nautical miles from the T0057 reference points.
-- Distance is never accepted from a caller: it is derived from two stored
-- positions and rounded once, so the same pair always settles the same amount.
create function private.airport_distance_nm(
    departure_icao text,
    arrival_icao text
)
returns numeric
language plpgsql
stable
set search_path = ''
as $$
declare
    departure public.airports%rowtype;
    arrival public.airports%rowtype;
    departure_latitude double precision;
    arrival_latitude double precision;
    half_chord double precision;
begin
    select airports.*
    into strict departure
    from public.airports as airports
    where airports.icao_code = airport_distance_nm.departure_icao;

    select airports.*
    into strict arrival
    from public.airports as airports
    where airports.icao_code = airport_distance_nm.arrival_icao;

    departure_latitude := radians(departure.latitude::double precision);
    arrival_latitude := radians(arrival.latitude::double precision);

    half_chord :=
        sin((arrival_latitude - departure_latitude) / 2) ^ 2
        + cos(departure_latitude)
        * cos(arrival_latitude)
        * sin(
            radians(
                (arrival.longitude - departure.longitude)::double precision
            ) / 2
        ) ^ 2;

    return round(
        (3440.065 * 2 * asin(sqrt(half_chord)))::numeric,
        2
    );
end;
$$;

revoke all on function private.airport_distance_nm(text, text) from public;
revoke all on function private.airport_distance_nm(text, text) from anon;
revoke all on function private.airport_distance_nm(text, text) from authenticated;
revoke all on function private.airport_distance_nm(text, text) from service_role;

create function private.airport_popularity_multiplier(
    popularity_tier text
)
returns numeric
language sql
immutable
set search_path = ''
as $$
    select case airport_popularity_multiplier.popularity_tier
        when 'regional' then (private.flight_settlement_policy() ->> 'multiplierRegional')::numeric
        when 'standard' then (private.flight_settlement_policy() ->> 'multiplierStandard')::numeric
        when 'major' then (private.flight_settlement_policy() ->> 'multiplierMajor')::numeric
        when 'hub' then (private.flight_settlement_policy() ->> 'multiplierHub')::numeric
    end;
$$;

revoke all on function private.airport_popularity_multiplier(text) from public;
revoke all on function private.airport_popularity_multiplier(text) from anon;
revoke all on function private.airport_popularity_multiplier(text) from authenticated;
revoke all on function private.airport_popularity_multiplier(text) from service_role;

-- Versioned flight reports. The client report only carries a closed outcome, a
-- bounded declared block time and optional bounded measurements; the settled
-- block time, the distance and the multiplier are the values the server itself
-- retained, stored so a settlement can be explained without recomputing it.
create table private.flight_reports (
    id uuid primary key default gen_random_uuid(),
    dispatch_id uuid not null references public.flight_dispatches (id) on delete cascade,
    outcome text not null,
    declared_block_minutes integer not null,
    settled_block_minutes integer not null,
    distance_nm numeric(8, 2) not null,
    hub_multiplier numeric(4, 3) not null,
    landing_vertical_speed_fpm integer,
    fuel_used_kg integer,
    recorded_at timestamptz not null default clock_timestamp(),
    schema_version integer not null default 1,
    constraint flight_reports_dispatch unique (dispatch_id),
    constraint flight_reports_outcome check (outcome in ('completed', 'interrupted')),
    constraint flight_reports_declared_block check (
        declared_block_minutes between 0 and 1440
    ),
    constraint flight_reports_settled_block check (
        settled_block_minutes between 0 and 1440
        and settled_block_minutes <= declared_block_minutes
    ),
    constraint flight_reports_distance check (distance_nm between 0 and 20000),
    constraint flight_reports_multiplier check (hub_multiplier between 0.5 and 2),
    constraint flight_reports_landing_rate check (
        landing_vertical_speed_fpm is null
        or landing_vertical_speed_fpm between -6000 and 6000
    ),
    constraint flight_reports_fuel check (
        fuel_used_kg is null or fuel_used_kg between 0 and 400000
    ),
    constraint flight_reports_schema_version check (schema_version = 1)
);

-- Informative reputation, append-only and without any direct Auth identifier.
-- No client role can write an event and no capability reads the score to decide
-- anything in the alpha.
create table private.company_reputation_events (
    id uuid primary key default gen_random_uuid(),
    company_id uuid not null references public.companies (id) on delete cascade,
    dispatch_id uuid not null references public.flight_dispatches (id) on delete cascade,
    delta integer not null,
    recorded_at timestamptz not null default clock_timestamp(),
    schema_version integer not null default 1,
    constraint company_reputation_events_dispatch unique (dispatch_id),
    constraint company_reputation_events_delta check (delta between -50 and 50),
    constraint company_reputation_events_schema_version check (schema_version = 1)
);

create table private.flight_close_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    idempotency_key uuid not null,
    company_id uuid not null references public.companies (id) on delete cascade,
    dispatch_id uuid not null references public.flight_dispatches (id) on delete cascade,
    report_id uuid not null references private.flight_reports (id) on delete cascade,
    reputation_event_id uuid not null references private.company_reputation_events (id) on delete cascade,
    ledger_entry_id uuid not null,
    payload_sha256 text not null,
    settled_amount_minor bigint not null,
    currency_code text not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, idempotency_key),
    constraint flight_close_commands_payload_hash check (
        payload_sha256 ~ '^[0-9a-f]{64}$'
    ),
    constraint flight_close_commands_dispatch unique (dispatch_id),
    constraint flight_close_commands_report unique (report_id),
    constraint flight_close_commands_reputation unique (reputation_event_id),
    constraint flight_close_commands_ledger unique (ledger_entry_id),
    constraint flight_close_commands_amount check (settled_amount_minor > 0),
    constraint flight_close_commands_currency check (currency_code ~ '^[A-Z]{3}$')
);

alter table private.flight_reports enable row level security;
alter table private.flight_reports force row level security;
alter table private.company_reputation_events enable row level security;
alter table private.company_reputation_events force row level security;
alter table private.flight_close_commands enable row level security;
alter table private.flight_close_commands force row level security;

revoke all on table private.flight_reports from public;
revoke all on table private.flight_reports from anon;
revoke all on table private.flight_reports from authenticated;
revoke all on table private.flight_reports from service_role;

revoke all on table private.company_reputation_events from public;
revoke all on table private.company_reputation_events from anon;
revoke all on table private.company_reputation_events from authenticated;
revoke all on table private.company_reputation_events from service_role;

revoke all on table private.flight_close_commands from public;
revoke all on table private.flight_close_commands from anon;
revoke all on table private.flight_close_commands from authenticated;
revoke all on table private.flight_close_commands from service_role;

comment on table private.flight_reports is
    'Versioned server-written flight reports, one per dispatch, carrying the bounded client outcome and the values the server retained for the settlement.';
comment on table private.company_reputation_events is
    'Append-only informative reputation deltas without a direct Auth identifier; no client role can write one and no capability is modulated by the resulting score.';
comment on table private.flight_close_commands is
    'Private idempotency registry binding one owner request to the single closure, report, reputation event and net ledger entry of a flight.';

create function private.reject_company_reputation_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise object_not_in_prerequisite_state using
        message = 'Reputation events are append-only.';
end;
$$;

revoke all on function private.reject_company_reputation_event_mutation() from public;
revoke all on function private.reject_company_reputation_event_mutation() from anon;
revoke all on function private.reject_company_reputation_event_mutation() from authenticated;
revoke all on function private.reject_company_reputation_event_mutation() from service_role;

create trigger company_reputation_events_reject_update_delete
before update or delete on private.company_reputation_events
for each row
execute function private.reject_company_reputation_event_mutation();

create trigger company_reputation_events_reject_truncate
before truncate on private.company_reputation_events
for each statement
execute function private.reject_company_reputation_event_mutation();

-- A dispatch can no longer be created while a terminal flight exists for the
-- same aircraft: the exclusivity check follows the partial index and only looks
-- at open dispatches. Signature, public contract, idempotency, locks and the
-- T0057 airport revalidation are unchanged.
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

    if not found then
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

-- The single authoritative closure. The caller brings a verified owner, an
-- idempotency key, a dispatch and a bounded report; every monetary input is
-- derived or recomputed here, under the company, subject and dispatch locks.
create function public.close_flight(
    owner_id uuid,
    idempotency_key uuid,
    dispatch_id uuid,
    report jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    policy jsonb := private.flight_settlement_policy();
    company public.companies%rowtype;
    subject private.financial_ledger_subjects%rowtype;
    dispatch public.flight_dispatches%rowtype;
    existing_command private.flight_close_commands%rowtype;
    stored_report private.flight_reports%rowtype;
    reputation_event private.company_reputation_events%rowtype;
    ledger_entry private.financial_ledger_entries%rowtype;
    report_keys text[];
    outcome text;
    declared_block_minutes integer;
    landing_vertical_speed_fpm integer;
    fuel_used_kg integer;
    settled_block_minutes integer;
    elapsed_minutes integer;
    distance_nm numeric;
    hub_multiplier numeric;
    settled_amount_minor bigint;
    ledger_currency text;
    ledger_currency_count bigint;
    next_sequence bigint;
    payload_hash text;
begin
    if owner_id is null or idempotency_key is null or dispatch_id is null
        or report is null
    then
        raise invalid_parameter_value using
            message = 'Owner, idempotency key, dispatch and report are required.';
    end if;

    if jsonb_typeof(report) <> 'object' then
        raise invalid_parameter_value using
            message = 'Flight report is invalid.';
    end if;

    select array_agg(keys.key order by keys.key)
    into report_keys
    from jsonb_object_keys(report) as keys(key);

    if report_keys is null
        or not (report_keys <@ array[
            'blockMinutes',
            'fuelUsedKg',
            'landingVerticalSpeedFpm',
            'outcome'
        ])
        or not (array['blockMinutes', 'outcome'] <@ report_keys)
    then
        raise invalid_parameter_value using
            message = 'Flight report is invalid.';
    end if;

    outcome := report ->> 'outcome';

    if outcome is null or outcome not in ('completed', 'interrupted')
        or jsonb_typeof(report -> 'blockMinutes') <> 'number'
        or (report -> 'blockMinutes')::text ~ '[.eE]'
    then
        raise invalid_parameter_value using
            message = 'Flight report is invalid.';
    end if;

    declared_block_minutes := (report ->> 'blockMinutes')::integer;

    if declared_block_minutes < 0
        or declared_block_minutes > (policy ->> 'maximumBlockMinutes')::integer
    then
        raise invalid_parameter_value using
            message = 'Flight report is invalid.';
    end if;

    if report ? 'landingVerticalSpeedFpm' then
        if jsonb_typeof(report -> 'landingVerticalSpeedFpm') <> 'number'
            or (report -> 'landingVerticalSpeedFpm')::text ~ '[.eE]'
        then
            raise invalid_parameter_value using
                message = 'Flight report is invalid.';
        end if;

        landing_vertical_speed_fpm := (report ->> 'landingVerticalSpeedFpm')::integer;

        if landing_vertical_speed_fpm < -6000 or landing_vertical_speed_fpm > 6000 then
            raise invalid_parameter_value using
                message = 'Flight report is invalid.';
        end if;
    end if;

    if report ? 'fuelUsedKg' then
        if jsonb_typeof(report -> 'fuelUsedKg') <> 'number'
            or (report -> 'fuelUsedKg')::text ~ '[.eE]'
        then
            raise invalid_parameter_value using
                message = 'Flight report is invalid.';
        end if;

        fuel_used_kg := (report ->> 'fuelUsedKg')::integer;

        if fuel_used_kg < 0 or fuel_used_kg > 400000 then
            raise invalid_parameter_value using
                message = 'Flight report is invalid.';
        end if;
    end if;

    payload_hash := encode(
        extensions.digest(
            convert_to(
                jsonb_build_object(
                    'blockMinutes', declared_block_minutes,
                    'dispatchId', dispatch_id,
                    'fuelUsedKg', fuel_used_kg,
                    'landingVerticalSpeedFpm', landing_vertical_speed_fpm,
                    'outcome', outcome
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
    where companies.owner_id = close_flight.owner_id
    for update;

    if not found or not private.account_is_active(close_flight.owner_id) then
        raise object_not_in_prerequisite_state using
            message = 'Flight closure is unavailable.';
    end if;

    select subjects.*
    into strict subject
    from private.financial_ledger_subjects as subjects
    where subjects.company_id = company.id
      and subjects.anonymized_at is null
    for update;

    select commands.*
    into existing_command
    from private.flight_close_commands as commands
    where commands.owner_id = close_flight.owner_id
      and commands.idempotency_key = close_flight.idempotency_key;

    if found then
        if existing_command.dispatch_id <> close_flight.dispatch_id
            or existing_command.payload_sha256 <> payload_hash
        then
            raise invalid_parameter_value using
                message = 'Idempotency key was already used with a different payload.';
        end if;

        select reports.*
        into strict stored_report
        from private.flight_reports as reports
        where reports.id = existing_command.report_id;

        select dispatches.*
        into strict dispatch
        from public.flight_dispatches as dispatches
        where dispatches.id = existing_command.dispatch_id;

        return jsonb_build_object(
            'aircraftId', dispatch.aircraft_id,
            'blockMinutes', stored_report.settled_block_minutes,
            'closedAt', dispatch.closed_at,
            'currencyCode', existing_command.currency_code,
            'dispatchId', dispatch.id,
            'distanceNm', stored_report.distance_nm,
            'ledgerEntryId', existing_command.ledger_entry_id,
            'outcome', stored_report.outcome,
            'schemaVersion', stored_report.schema_version,
            'settledAmountMinor', existing_command.settled_amount_minor,
            'state', dispatch.state
        );
    end if;

    select dispatches.*
    into dispatch
    from public.flight_dispatches as dispatches
    where dispatches.id = close_flight.dispatch_id
      and dispatches.company_id = company.id
    for update;

    if not found or dispatch.state <> 'active' then
        raise object_not_in_prerequisite_state using
            message = 'Dispatch is unavailable for closure.';
    end if;

    elapsed_minutes := greatest(
        floor(
            extract(epoch from (clock_timestamp() - dispatch.started_at)) / 60
        )::integer,
        0
    );
    settled_block_minutes := least(declared_block_minutes, elapsed_minutes);

    distance_nm := private.airport_distance_nm(
        dispatch.departure_icao,
        dispatch.arrival_icao
    );

    select round(
        (
            private.airport_popularity_multiplier(departure.popularity_tier)
            + private.airport_popularity_multiplier(arrival.popularity_tier)
        ) / 2,
        3
    )
    into strict hub_multiplier
    from public.airports as departure
    cross join public.airports as arrival
    where departure.icao_code = dispatch.departure_icao
      and arrival.icao_code = dispatch.arrival_icao;

    settled_amount_minor := least(
        round(
            (
                (policy ->> 'baseAmountMinor')::numeric
                + (policy ->> 'perNauticalMileMinor')::numeric * distance_nm
                + (policy ->> 'perBlockMinuteMinor')::numeric * settled_block_minutes
            ) * hub_multiplier
        )::bigint,
        (policy ->> 'perFlightCapMinor')::bigint
    );

    if outcome = 'interrupted' then
        settled_amount_minor := (policy ->> 'interruptedFloorMinor')::bigint;
    end if;

    select
        min(entries.currency_code),
        count(distinct entries.currency_code),
        coalesce(max(entries.sequence_number), 0) + 1
    into ledger_currency, ledger_currency_count, next_sequence
    from private.financial_ledger_entries as entries
    where entries.subject_id = subject.subject_id;

    if ledger_currency_count <> 1
        or ledger_currency <> (policy ->> 'currencyCode')
    then
        raise object_not_in_prerequisite_state using
            message = 'Settlement currency does not match the company ledger.';
    end if;

    update public.flight_dispatches as dispatches
    set state = case when outcome = 'completed' then 'completed' else 'interrupted' end
    where dispatches.id = dispatch.id
    returning *
    into dispatch;

    insert into private.flight_reports (
        dispatch_id,
        outcome,
        declared_block_minutes,
        settled_block_minutes,
        distance_nm,
        hub_multiplier,
        landing_vertical_speed_fpm,
        fuel_used_kg
    )
    values (
        dispatch.id,
        outcome,
        declared_block_minutes,
        settled_block_minutes,
        distance_nm,
        hub_multiplier,
        landing_vertical_speed_fpm,
        fuel_used_kg
    )
    returning *
    into stored_report;

    insert into private.company_reputation_events (
        company_id,
        dispatch_id,
        delta
    )
    values (
        company.id,
        dispatch.id,
        case
            when outcome = 'completed'
                then (policy ->> 'reputationCompletedDelta')::integer
            else (policy ->> 'reputationInterruptedDelta')::integer
        end
    )
    returning *
    into reputation_event;

    insert into private.financial_ledger_entries (
        subject_id,
        sequence_number,
        idempotency_key,
        entry_type,
        amount_minor,
        currency_code
    )
    values (
        subject.subject_id,
        next_sequence,
        close_flight.idempotency_key,
        'flight_settlement',
        settled_amount_minor,
        (policy ->> 'currencyCode')
    )
    returning *
    into ledger_entry;

    insert into private.flight_close_commands (
        owner_id,
        idempotency_key,
        company_id,
        dispatch_id,
        report_id,
        reputation_event_id,
        ledger_entry_id,
        payload_sha256,
        settled_amount_minor,
        currency_code
    )
    values (
        close_flight.owner_id,
        close_flight.idempotency_key,
        company.id,
        dispatch.id,
        stored_report.id,
        reputation_event.id,
        ledger_entry.id,
        payload_hash,
        settled_amount_minor,
        ledger_entry.currency_code
    );

    return jsonb_build_object(
        'aircraftId', dispatch.aircraft_id,
        'blockMinutes', stored_report.settled_block_minutes,
        'closedAt', dispatch.closed_at,
        'currencyCode', ledger_entry.currency_code,
        'dispatchId', dispatch.id,
        'distanceNm', stored_report.distance_nm,
        'ledgerEntryId', ledger_entry.id,
        'outcome', stored_report.outcome,
        'schemaVersion', stored_report.schema_version,
        'settledAmountMinor', settled_amount_minor,
        'state', dispatch.state
    );
end;
$$;

revoke all on function public.close_flight(uuid, uuid, uuid, jsonb) from public;
revoke all on function public.close_flight(uuid, uuid, uuid, jsonb) from anon;
revoke all on function public.close_flight(uuid, uuid, uuid, jsonb) from authenticated;
grant execute on function public.close_flight(uuid, uuid, uuid, jsonb) to service_role;

-- The only reputation read. It derives the company from the Auth subject, never
-- from an argument, and returns a bounded score that decides nothing.
create function public.get_company_reputation()
returns table (
    score integer,
    event_count bigint,
    schema_version integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    policy jsonb := private.flight_settlement_policy();
    actor_id uuid := auth.uid();
begin
    if actor_id is null
        or coalesce(auth.jwt() ->> 'role', '') <> 'authenticated'
        or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
    then
        raise insufficient_privilege using
            message = 'Company reputation access is not permitted.';
    end if;

    return query
    select
        greatest(
            (policy ->> 'reputationMinimumScore')::integer,
            least(
                (policy ->> 'reputationMaximumScore')::integer,
                (policy ->> 'reputationBaseScore')::integer
                + coalesce(sum(events.delta), 0)
            )
        )::integer,
        count(events.id)::bigint,
        1
    from public.companies as companies
    left join private.company_reputation_events as events
      on events.company_id = companies.id
    where companies.owner_id = actor_id
    group by companies.id;
end;
$$;

revoke all on function public.get_company_reputation() from public;
revoke all on function public.get_company_reputation() from anon;
grant execute on function public.get_company_reputation() to authenticated;

comment on function public.get_company_reputation() is
    'Owner-scoped informative reputation score, clamped by the canonical settlement policy and never used to allow or deny a capability.';
