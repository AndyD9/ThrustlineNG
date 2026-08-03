begin;

select plan(28);

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('57000000-0000-4000-8000-000000000001', 'airport-a@thrustline.invalid', '{}', false),
    ('57000000-0000-4000-8000-000000000002', 'airport-b@thrustline.invalid', '{}', false);

insert into public.companies (id, owner_id, name)
values
    ('57100000-0000-4000-8000-000000000001', '57000000-0000-4000-8000-000000000001', 'Airport Alpha Air'),
    ('57100000-0000-4000-8000-000000000002', '57000000-0000-4000-8000-000000000002', 'Airport Bravo Air');

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor,
    currency_code, status, sold_at
)
values
    ('57200000-0000-4000-8000-000000000001', 'C172', 'APT-C172-0001', 'Airport Cessna One', 1, 'EUR', 'sold', clock_timestamp()),
    ('57200000-0000-4000-8000-000000000002', 'C172', 'APT-C172-0002', 'Airport Cessna Two', 1, 'EUR', 'sold', clock_timestamp()),
    ('57200000-0000-4000-8000-000000000003', 'C172', 'APT-C172-0003', 'Airport Cessna Three', 1, 'EUR', 'sold', clock_timestamp());

insert into public.company_aircraft (
    id, company_id, offer_id, aircraft_type_code, serial_number, display_name
)
values
    ('57300000-0000-4000-8000-000000000001', '57100000-0000-4000-8000-000000000001', '57200000-0000-4000-8000-000000000001', 'C172', 'APT-C172-0001', 'Airport Cessna One'),
    ('57300000-0000-4000-8000-000000000002', '57100000-0000-4000-8000-000000000001', '57200000-0000-4000-8000-000000000002', 'C172', 'APT-C172-0002', 'Airport Cessna Two'),
    ('57300000-0000-4000-8000-000000000003', '57100000-0000-4000-8000-000000000001', '57200000-0000-4000-8000-000000000003', 'C172', 'APT-C172-0003', 'Airport Cessna Three');

-- The loaded reference must match the bounds declared by eng/airports.json.
select ok(
    (select count(*) from public.airports) between 1 and 200,
    'the loaded reference stays inside its declared size bound'
);
select is_empty(
    $$select icao_code from public.airports
      where latitude < -90 or latitude > 90
         or longitude < -180 or longitude > 180$$,
    'the loaded reference stays inside its declared bounds'
);
select is_empty(
    $$select icao_code from public.airports
      where popularity_tier not in ('regional', 'standard', 'major', 'hub')$$,
    'every popularity tier belongs to the closed list'
);
select is(
    (select count(distinct icao_code) from public.airports),
    (select count(*) from public.airports),
    'ICAO codes are unique in the loaded reference'
);
select is(
    (select count(distinct popularity_tier) from public.airports),
    4::bigint,
    'the reference uses exactly four ordered tiers'
);

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"57000000-0000-4000-8000-000000000001"}', true);
set local role authenticated;
select ok(
    (select count(*) from public.airports) > 0,
    'A can read the aerodrome reference'
);
select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('ZZZA', 'Forged Field', 1.0, 1.0, 'hub')$$,
    '42501', 'permission denied for table airports',
    'authenticated cannot insert an aerodrome'
);
select throws_ok(
    $$update public.airports set popularity_tier = 'hub'$$,
    '42501', 'permission denied for table airports',
    'authenticated cannot update an aerodrome'
);
select throws_ok(
    $$delete from public.airports$$,
    '42501', 'permission denied for table airports',
    'authenticated cannot delete an aerodrome'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"57000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select ok(
    (select count(*) from public.airports) > 0,
    'B can read the same aerodrome reference'
);
reset role;

set local role anon;
select throws_ok(
    'select * from public.airports',
    '42501', 'permission denied for table airports',
    'anonymous cannot read the aerodrome reference'
);
reset role;

set local role service_role;
select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('ZZZB', 'Forged Field', 1.0, 1.0, 'hub')$$,
    '42501', 'permission denied for table airports',
    'service role cannot mutate the reference directly'
);
reset role;

select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('LFPG', 'Duplicate Field', 1.0, 1.0, 'hub')$$,
    '23505', 'duplicate key value violates unique constraint "airports_pkey"',
    'a duplicate ICAO code is rejected'
);
select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('ZZZC', 'Out Of Bounds Field', 91.0, 1.0, 'hub')$$,
    '23514', 'new row for relation "airports" violates check constraint "airports_latitude_bounds"',
    'an out-of-bounds latitude is rejected'
);
select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('ZZZD', 'Out Of Bounds Field', 1.0, -181.0, 'hub')$$,
    '23514', 'new row for relation "airports" violates check constraint "airports_longitude_bounds"',
    'an out-of-bounds longitude is rejected'
);
select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('ZZZE', 'Unknown Tier Field', 1.0, 1.0, 'mega')$$,
    '23514', 'new row for relation "airports" violates check constraint "airports_popularity_tier"',
    'an unknown popularity tier is rejected'
);
select throws_ok(
    $$insert into public.airports (
        icao_code, name, latitude, longitude, popularity_tier, schema_version
      ) values ('ZZZF', 'Unknown Version Field', 1.0, 1.0, 'hub', 2)$$,
    '23514', 'new row for relation "airports" violates check constraint "airports_schema_version"',
    'an unknown schema version is rejected'
);
select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('zzzg', 'Malformed Code Field', 1.0, 1.0, 'hub')$$,
    '23514', 'new row for relation "airports" violates check constraint "airports_icao_code_format"',
    'a malformed reference ICAO code is rejected'
);
select throws_ok(
    $$insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
      values ('ZZZH', ' Untrimmed Field ', 1.0, 1.0, 'hub')$$,
    '23514', 'new row for relation "airports" violates check constraint "airports_name_bounded"',
    'an untrimmed aerodrome name is rejected'
);

-- Replay the exact shape of the seed load to prove it converges instead of
-- duplicating or drifting.
select set_config(
    't0057.airport_count',
    (select count(*) from public.airports)::text,
    true
);
insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
values ('LFPG', 'Paris Charles de Gaulle', 49.0097, 2.5479, 'hub')
on conflict (icao_code) do update
set name = excluded.name,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    popularity_tier = excluded.popularity_tier;
select is(
    (select count(*) from public.airports),
    current_setting('t0057.airport_count')::bigint,
    'replaying the seed load does not duplicate an aerodrome'
);
select is(
    (select name || '|' || latitude || '|' || longitude || '|' || popularity_tier
     from public.airports where icao_code = 'LFPG'),
    'Paris Charles de Gaulle|49.0097|2.5479|hub',
    'the replayed seed load converges on the canonical row'
);

set local role service_role;
select set_config(
    't0057.dispatch_response',
    public.create_dispatch_draft(
        '57000000-0000-4000-8000-000000000001',
        '57400000-0000-4000-8000-000000000001',
        '57300000-0000-4000-8000-000000000001',
        'LFPG', 'LFPO'
    )::text,
    true
);
reset role;

select is(
    current_setting('t0057.dispatch_response')::jsonb ->> 'state',
    'draft',
    'two known aerodromes create one draft'
);

set local role service_role;
select is(
    public.create_dispatch_draft(
        '57000000-0000-4000-8000-000000000001',
        '57400000-0000-4000-8000-000000000001',
        '57300000-0000-4000-8000-000000000001',
        'LFPG', 'LFPO'
    )::text,
    current_setting('t0057.dispatch_response'),
    'the T0047 replay contract is unchanged'
);
select set_config(
    't0057.normalized_response',
    public.create_dispatch_draft(
        '57000000-0000-4000-8000-000000000001',
        '57400000-0000-4000-8000-000000000002',
        '57300000-0000-4000-8000-000000000002',
        ' lfml ', 'lfbo'
    )::text,
    true
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '57000000-0000-4000-8000-000000000001',
        '57400000-0000-4000-8000-000000000003',
        '57300000-0000-4000-8000-000000000003',
        'ZZZZ', 'LFPO'
    )$$,
    '22023', 'Departure and arrival must be distinct four-character ICAO codes.',
    'an unknown departure aerodrome is rejected without naming the reference'
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '57000000-0000-4000-8000-000000000001',
        '57400000-0000-4000-8000-000000000004',
        '57300000-0000-4000-8000-000000000003',
        'LFPG', 'ZZZZ'
    )$$,
    '22023', 'Departure and arrival must be distinct four-character ICAO codes.',
    'an unknown arrival aerodrome is rejected identically'
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '57000000-0000-4000-8000-000000000001',
        '57400000-0000-4000-8000-000000000005',
        '57300000-0000-4000-8000-000000000003',
        'ABC', 'LFPO'
    )$$,
    '22023', 'Departure and arrival must be distinct four-character ICAO codes.',
    'a malformed code and an unknown code fail identically'
);
reset role;

select results_eq(
    $$select departure_icao, arrival_icao from public.flight_dispatches
      where aircraft_id = '57300000-0000-4000-8000-000000000002'$$,
    $$values ('LFML'::text, 'LFBO'::text)$$,
    'a lowercase known aerodrome is normalized and accepted'
);
select results_eq(
    $$select count(*)::bigint from public.flight_dispatches
      where aircraft_id = '57300000-0000-4000-8000-000000000003'$$,
    array[0::bigint],
    'a rejected aerodrome leaves no dispatch'
);

select * from finish();
rollback;
