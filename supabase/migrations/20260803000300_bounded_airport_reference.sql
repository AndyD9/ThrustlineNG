create table public.airports (
    icao_code text primary key,
    name text not null,
    latitude numeric(7, 4) not null,
    longitude numeric(8, 4) not null,
    popularity_tier text not null,
    schema_version integer not null default 1,
    constraint airports_icao_code_format check (icao_code ~ '^[A-Z0-9]{4}$'),
    constraint airports_name_bounded check (
        name = btrim(name) and length(name) between 1 and 64
    ),
    constraint airports_latitude_bounds check (latitude >= -90 and latitude <= 90),
    constraint airports_longitude_bounds check (longitude >= -180 and longitude <= 180),
    constraint airports_popularity_tier check (
        popularity_tier in ('regional', 'standard', 'major', 'hub')
    ),
    constraint airports_schema_version check (schema_version = 1)
);

alter table public.airports enable row level security;
alter table public.airports force row level security;

revoke all on table public.airports from public;
revoke all on table public.airports from anon;
revoke all on table public.airports from authenticated;
revoke all on table public.airports from service_role;
grant select on table public.airports to authenticated;

create policy airports_select_reference
on public.airports
for select
to authenticated
using (true);

comment on table public.airports is
    'Bounded server-owned aerodrome reference carrying ICAO code, position and popularity tier; read-only for authenticated roles and never mutable by a client. Loaded from eng/airports.json, which stays the canonical source.';
comment on column public.airports.popularity_tier is
    'One of four ordered alpha tiers, from regional to hub. The reference only assigns a tier and never carries a monetary value; pricing belongs to the settlement policy that reads it.';

-- Airport awareness for the T0047 dispatch command. The signature, the public
-- contract, the idempotency registry and the existing locks are unchanged: only
-- the bounded validation gains a reference lookup, so a draft can never name an
-- aerodrome the server cannot later position. Unknown codes deliberately reuse
-- the existing malformed-code message, which keeps an unknown aerodrome
-- indistinguishable from an invalid one and prevents reference enumeration.
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
