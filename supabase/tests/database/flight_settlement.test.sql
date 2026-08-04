begin;

select plan(39);

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('a1000000-0000-4000-8000-000000000001', 'settle-a@thrustline.invalid', '{}', false),
    ('a2000000-0000-4000-8000-000000000002', 'settle-b@thrustline.invalid', '{}', false),
    ('a3000000-0000-4000-8000-000000000003', 'settle-pending@thrustline.invalid', '{}', false),
    ('a4000000-0000-4000-8000-000000000004', 'settle-rollback@thrustline.invalid', '{}', false),
    ('a5000000-0000-4000-8000-000000000005', 'settle-high@thrustline.invalid', '{}', false),
    ('a6000000-0000-4000-8000-000000000006', 'settle-low@thrustline.invalid', '{}', false);

insert into public.companies (id, owner_id, name)
values
    ('a1100000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'Settle Alpha Air'),
    ('a2100000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000002', 'Settle Bravo Air'),
    ('a3100000-0000-4000-8000-000000000003', 'a3000000-0000-4000-8000-000000000003', 'Settle Pending Air'),
    ('a4100000-0000-4000-8000-000000000004', 'a4000000-0000-4000-8000-000000000004', 'Settle Rollback Air'),
    ('a5100000-0000-4000-8000-000000000005', 'a5000000-0000-4000-8000-000000000005', 'Settle High Air'),
    ('a6100000-0000-4000-8000-000000000006', 'a6000000-0000-4000-8000-000000000006', 'Settle Low Air');

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor,
    currency_code, status, sold_at
)
values
    ('a1200000-0000-4000-8000-000000000001', 'C172', 'STL-C172-0001', 'Settle Cessna A1', 1, 'EUR', 'sold', clock_timestamp()),
    ('a1200000-0000-4000-8000-000000000002', 'C172', 'STL-C172-0002', 'Settle Cessna A2', 1, 'EUR', 'sold', clock_timestamp()),
    ('a1200000-0000-4000-8000-000000000003', 'C172', 'STL-C172-0003', 'Settle Cessna A3', 1, 'EUR', 'sold', clock_timestamp()),
    ('a2200000-0000-4000-8000-000000000002', 'C172', 'STL-C172-0004', 'Settle Cessna B1', 1, 'EUR', 'sold', clock_timestamp()),
    ('a3200000-0000-4000-8000-000000000003', 'C172', 'STL-C172-0005', 'Settle Cessna P1', 1, 'EUR', 'sold', clock_timestamp()),
    ('a4200000-0000-4000-8000-000000000004', 'C172', 'STL-C172-0006', 'Settle Cessna R1', 1, 'EUR', 'sold', clock_timestamp()),
    ('a5200000-0000-4000-8000-000000000005', 'C172', 'STL-C172-0007', 'Settle Cessna C1', 1, 'EUR', 'sold', clock_timestamp()),
    ('a5200000-0000-4000-8000-000000000006', 'C172', 'STL-C172-0008', 'Settle Cessna C2', 1, 'EUR', 'sold', clock_timestamp()),
    ('a6200000-0000-4000-8000-000000000006', 'C172', 'STL-C172-0009', 'Settle Cessna D1', 1, 'EUR', 'sold', clock_timestamp()),
    ('a6200000-0000-4000-8000-000000000007', 'C172', 'STL-C172-0010', 'Settle Cessna D2', 1, 'EUR', 'sold', clock_timestamp());

insert into public.company_aircraft (
    id, company_id, offer_id, aircraft_type_code, serial_number, display_name
)
values
    ('a1300000-0000-4000-8000-000000000001', 'a1100000-0000-4000-8000-000000000001', 'a1200000-0000-4000-8000-000000000001', 'C172', 'STL-C172-0001', 'Settle Cessna A1'),
    ('a1300000-0000-4000-8000-000000000002', 'a1100000-0000-4000-8000-000000000001', 'a1200000-0000-4000-8000-000000000002', 'C172', 'STL-C172-0002', 'Settle Cessna A2'),
    ('a1300000-0000-4000-8000-000000000003', 'a1100000-0000-4000-8000-000000000001', 'a1200000-0000-4000-8000-000000000003', 'C172', 'STL-C172-0003', 'Settle Cessna A3'),
    ('a2300000-0000-4000-8000-000000000002', 'a2100000-0000-4000-8000-000000000002', 'a2200000-0000-4000-8000-000000000002', 'C172', 'STL-C172-0004', 'Settle Cessna B1'),
    ('a3300000-0000-4000-8000-000000000003', 'a3100000-0000-4000-8000-000000000003', 'a3200000-0000-4000-8000-000000000003', 'C172', 'STL-C172-0005', 'Settle Cessna P1'),
    ('a4300000-0000-4000-8000-000000000004', 'a4100000-0000-4000-8000-000000000004', 'a4200000-0000-4000-8000-000000000004', 'C172', 'STL-C172-0006', 'Settle Cessna R1'),
    ('a5300000-0000-4000-8000-000000000005', 'a5100000-0000-4000-8000-000000000005', 'a5200000-0000-4000-8000-000000000005', 'C172', 'STL-C172-0007', 'Settle Cessna C1'),
    ('a5300000-0000-4000-8000-000000000006', 'a5100000-0000-4000-8000-000000000005', 'a5200000-0000-4000-8000-000000000006', 'C172', 'STL-C172-0008', 'Settle Cessna C2'),
    ('a6300000-0000-4000-8000-000000000006', 'a6100000-0000-4000-8000-000000000006', 'a6200000-0000-4000-8000-000000000006', 'C172', 'STL-C172-0009', 'Settle Cessna D1'),
    ('a6300000-0000-4000-8000-000000000007', 'a6100000-0000-4000-8000-000000000006', 'a6200000-0000-4000-8000-000000000007', 'C172', 'STL-C172-0010', 'Settle Cessna D2');

set local role service_role;
select public.post_company_opening_balance(
    'a1100000-0000-4000-8000-000000000001',
    'a1a00000-0000-4000-8000-000000000001', 43000000, 'EUR'
);
select public.post_company_opening_balance(
    'a2100000-0000-4000-8000-000000000002',
    'a2a00000-0000-4000-8000-000000000002', 43000000, 'EUR'
);
select public.post_company_opening_balance(
    'a4100000-0000-4000-8000-000000000004',
    'a4a00000-0000-4000-8000-000000000004', 43000000, 'EUR'
);

-- Three owned flights for A, one interrupted flight for B, one blocked owner and
-- one rollback owner. Every dispatch is created and started by the delivered
-- T0047 and T0050 commands, never by a direct insert.
select set_config('t0051.dispatch_a1', public.create_dispatch_draft('a1000000-0000-4000-8000-000000000001', 'a1400000-0000-4000-8000-000000000001', 'a1300000-0000-4000-8000-000000000001', 'LFBO', 'LFML') ->> 'dispatchId', true);
select set_config('t0051.dispatch_a2', public.create_dispatch_draft('a1000000-0000-4000-8000-000000000001', 'a1400000-0000-4000-8000-000000000002', 'a1300000-0000-4000-8000-000000000002', 'LFPG', 'LFPO') ->> 'dispatchId', true);
select set_config('t0051.dispatch_a3', public.create_dispatch_draft('a1000000-0000-4000-8000-000000000001', 'a1400000-0000-4000-8000-000000000003', 'a1300000-0000-4000-8000-000000000003', 'LEMD', 'NZAA') ->> 'dispatchId', true);
select set_config('t0051.dispatch_b1', public.create_dispatch_draft('a2000000-0000-4000-8000-000000000002', 'a2400000-0000-4000-8000-000000000002', 'a2300000-0000-4000-8000-000000000002', 'LFBO', 'LFML') ->> 'dispatchId', true);
select set_config('t0051.dispatch_p1', public.create_dispatch_draft('a3000000-0000-4000-8000-000000000003', 'a3400000-0000-4000-8000-000000000003', 'a3300000-0000-4000-8000-000000000003', 'LFPG', 'LFBO') ->> 'dispatchId', true);
select set_config('t0051.dispatch_r1', public.create_dispatch_draft('a4000000-0000-4000-8000-000000000004', 'a4400000-0000-4000-8000-000000000004', 'a4300000-0000-4000-8000-000000000004', 'LFPO', 'LFML') ->> 'dispatchId', true);
select set_config('t0051.dispatch_c1', public.create_dispatch_draft('a5000000-0000-4000-8000-000000000005', 'a5400000-0000-4000-8000-000000000005', 'a5300000-0000-4000-8000-000000000005', 'EGLL', 'EGCC') ->> 'dispatchId', true);
select set_config('t0051.dispatch_c2', public.create_dispatch_draft('a5000000-0000-4000-8000-000000000005', 'a5400000-0000-4000-8000-000000000006', 'a5300000-0000-4000-8000-000000000006', 'EGKK', 'EGBB') ->> 'dispatchId', true);
select set_config('t0051.dispatch_d1', public.create_dispatch_draft('a6000000-0000-4000-8000-000000000006', 'a6400000-0000-4000-8000-000000000006', 'a6300000-0000-4000-8000-000000000006', 'EDDF', 'EDDM') ->> 'dispatchId', true);
select set_config('t0051.dispatch_d2', public.create_dispatch_draft('a6000000-0000-4000-8000-000000000006', 'a6400000-0000-4000-8000-000000000007', 'a6300000-0000-4000-8000-000000000007', 'EDDH', 'EDDK') ->> 'dispatchId', true);

select public.start_flight_from_dispatch('a1000000-0000-4000-8000-000000000001', 'a1500000-0000-4000-8000-000000000001', current_setting('t0051.dispatch_a1')::uuid);
select public.start_flight_from_dispatch('a1000000-0000-4000-8000-000000000001', 'a1500000-0000-4000-8000-000000000002', current_setting('t0051.dispatch_a2')::uuid);
select public.start_flight_from_dispatch('a1000000-0000-4000-8000-000000000001', 'a1500000-0000-4000-8000-000000000003', current_setting('t0051.dispatch_a3')::uuid);
select public.start_flight_from_dispatch('a2000000-0000-4000-8000-000000000002', 'a2500000-0000-4000-8000-000000000002', current_setting('t0051.dispatch_b1')::uuid);
select public.start_flight_from_dispatch('a3000000-0000-4000-8000-000000000003', 'a3500000-0000-4000-8000-000000000003', current_setting('t0051.dispatch_p1')::uuid);
select public.start_flight_from_dispatch('a4000000-0000-4000-8000-000000000004', 'a4500000-0000-4000-8000-000000000004', current_setting('t0051.dispatch_r1')::uuid);
reset role;

-- Simulated elapsed flight time. The trigger owns started_at, so the only way to
-- observe a real block time inside one transaction is to disable it, backdate the
-- recorded departure and restore it immediately.
alter table public.flight_dispatches disable trigger flight_dispatches_server_started_at;
update public.flight_dispatches
set started_at = clock_timestamp() - interval '75 minutes'
where id in (
    current_setting('t0051.dispatch_a1')::uuid,
    current_setting('t0051.dispatch_a2')::uuid,
    current_setting('t0051.dispatch_b1')::uuid
);
update public.flight_dispatches
set started_at = clock_timestamp() - interval '1441 minutes'
where id = current_setting('t0051.dispatch_a3')::uuid;
alter table public.flight_dispatches enable trigger flight_dispatches_server_started_at;

set local role authenticated;
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1600000-0000-4000-8000-000000000001',
        current_setting('t0051.dispatch_a1')::uuid,
        '{"outcome":"completed","blockMinutes":100}'::jsonb
    )$$,
    '42501', 'permission denied for function close_flight',
    'authenticated cannot execute the flight closure command'
);
select throws_ok(
    $$update public.flight_dispatches
      set state = 'completed', closed_at = clock_timestamp()$$,
    '42501', 'permission denied for table flight_dispatches',
    'authenticated cannot forge a terminal state or a closing time'
);
reset role;

set local role service_role;
select set_config(
    't0051.close_a1',
    public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1600000-0000-4000-8000-000000000001',
        current_setting('t0051.dispatch_a1')::uuid,
        '{"outcome":"completed","blockMinutes":100,"landingVerticalSpeedFpm":-180,"fuelUsedKg":420}'::jsonb
    )::text,
    true
);
reset role;

select is(
    current_setting('t0051.close_a1')::jsonb ->> 'settledAmountMinor',
    '57694',
    'a 168.28 NM standard-to-standard flight of 75 block minutes settles the exact scale amount'
);
select is(
    current_setting('t0051.close_a1')::jsonb ->> 'distanceNm',
    '168.28',
    'the distance comes from the airport reference'
);
select is(
    current_setting('t0051.close_a1')::jsonb ->> 'blockMinutes',
    '75',
    'a declared block time above the server elapsed time is reduced to the server time'
);
select is(
    current_setting('t0051.close_a1')::jsonb ->> 'currencyCode',
    'EUR',
    'the settlement currency comes from the canonical policy'
);
select results_eq(
    $$select state, closed_at is not null, started_at is not null
      from public.flight_dispatches
      where id = current_setting('t0051.dispatch_a1')::uuid$$,
    $$values ('completed'::text, true, true)$$,
    'the flight reaches a terminal state with a server closing time and keeps its departure'
);
select results_eq(
    $$select outcome, declared_block_minutes, settled_block_minutes,
        distance_nm, hub_multiplier, landing_vertical_speed_fpm, fuel_used_kg
      from private.flight_reports
      where dispatch_id = current_setting('t0051.dispatch_a1')::uuid$$,
    $$values (
        'completed'::text, 100, 75, 168.28::numeric(8,2), 1.000::numeric(4,3), -180, 420
      )$$,
    'the bounded report is stored once with the values the server retained'
);
select results_eq(
    $$select entry_type, amount_minor, currency_code
      from private.financial_ledger_entries as entries
      join private.financial_ledger_subjects as subjects
        on subjects.subject_id = entries.subject_id
      where subjects.company_id = 'a1100000-0000-4000-8000-000000000001'
      order by entries.sequence_number$$,
    $$values
        ('opening_balance'::text, 43000000::bigint, 'EUR'::text),
        ('flight_settlement'::text, 57694::bigint, 'EUR'::text)$$,
    'the closure appends exactly one positive net entry to the immutable ledger'
);
select results_eq(
    $$select delta from private.company_reputation_events
      where dispatch_id = current_setting('t0051.dispatch_a1')::uuid$$,
    array[1],
    'a completed flight records a single +1 reputation event'
);

set local role service_role;
select is(
    public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1600000-0000-4000-8000-000000000001',
        current_setting('t0051.dispatch_a1')::uuid,
        '{"outcome":"completed","blockMinutes":100,"landingVerticalSpeedFpm":-180,"fuelUsedKg":420}'::jsonb
    )::text,
    current_setting('t0051.close_a1'),
    'an identical closure replays with the same response'
);
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1600000-0000-4000-8000-000000000001',
        current_setting('t0051.dispatch_a2')::uuid,
        '{"outcome":"completed","blockMinutes":100}'::jsonb
    )$$,
    '22023', 'Idempotency key was already used with a different payload.',
    'a closure key reused with another payload is rejected'
);
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1700000-0000-4000-8000-000000000001',
        current_setting('t0051.dispatch_a1')::uuid,
        '{"outcome":"completed","blockMinutes":100}'::jsonb
    )$$,
    '55000', 'Dispatch is unavailable for closure.',
    'a second closure of the same flight is rejected'
);
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1700000-0000-4000-8000-000000000002',
        current_setting('t0051.dispatch_b1')::uuid,
        '{"outcome":"completed","blockMinutes":100}'::jsonb
    )$$,
    '55000', 'Dispatch is unavailable for closure.',
    'owner A cannot close owner B flight'
);
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1700000-0000-4000-8000-000000000003',
        'a1900000-0000-4000-8000-000000000009',
        '{"outcome":"completed","blockMinutes":100}'::jsonb
    )$$,
    '55000', 'Dispatch is unavailable for closure.',
    'an unknown flight fails closed with the same message'
);
select throws_ok(
    $$select public.close_flight(
        'a5000000-0000-4000-8000-000000000005',
        'a5700000-0000-4000-8000-000000000005',
        current_setting('t0051.dispatch_c1')::uuid,
        '{"outcome":"completed","blockMinutes":100}'::jsonb
    )$$,
    '55000', 'Dispatch is unavailable for closure.',
    'a draft that never departed cannot be closed'
);
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1700000-0000-4000-8000-000000000004',
        current_setting('t0051.dispatch_a2')::uuid,
        '{"outcome":"completed","blockMinutes":1441}'::jsonb
    )$$,
    '22023', 'Flight report is invalid.',
    'a declared block time above the policy maximum is rejected'
);
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1700000-0000-4000-8000-000000000005',
        current_setting('t0051.dispatch_a2')::uuid,
        '{"outcome":"completed","blockMinutes":100,"settledAmountMinor":900000}'::jsonb
    )$$,
    '22023', 'Flight report is invalid.',
    'a report carrying a monetary field is rejected'
);
select throws_ok(
    $$select public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1700000-0000-4000-8000-000000000006',
        current_setting('t0051.dispatch_a2')::uuid,
        '{"outcome":"diverted","blockMinutes":100}'::jsonb
    )$$,
    '22023', 'Flight report is invalid.',
    'an outcome outside the closed list is rejected'
);

-- The A2 flight declares the policy maximum while the server only measured 75
-- minutes, and the A3 flight would settle above the per-flight cap.
select set_config(
    't0051.close_a2',
    public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1600000-0000-4000-8000-000000000002',
        current_setting('t0051.dispatch_a2')::uuid,
        '{"outcome":"completed","blockMinutes":1440}'::jsonb
    )::text,
    true
);
select set_config(
    't0051.close_a3',
    public.close_flight(
        'a1000000-0000-4000-8000-000000000001',
        'a1600000-0000-4000-8000-000000000003',
        current_setting('t0051.dispatch_a3')::uuid,
        '{"outcome":"completed","blockMinutes":1440}'::jsonb
    )::text,
    true
);
select set_config(
    't0051.close_b1',
    public.close_flight(
        'a2000000-0000-4000-8000-000000000002',
        'a2600000-0000-4000-8000-000000000002',
        current_setting('t0051.dispatch_b1')::uuid,
        '{"outcome":"interrupted","blockMinutes":100}'::jsonb
    )::text,
    true
);
reset role;

select results_eq(
    $$values (
        (current_setting('t0051.close_a2')::jsonb ->> 'settledAmountMinor'),
        (current_setting('t0051.close_a2')::jsonb ->> 'blockMinutes')
      )$$,
    $$values ('48648'::text, '75'::text)$$,
    'a 18.44 NM hub-to-major flight settles the exact scale amount on the server block time'
);
select is(
    current_setting('t0051.close_a3')::jsonb ->> 'settledAmountMinor',
    '2000000',
    'a settlement above the per-flight cap is bounded by the cap'
);
select results_eq(
    $$values (
        (current_setting('t0051.close_b1')::jsonb ->> 'settledAmountMinor'),
        (current_setting('t0051.close_b1')::jsonb ->> 'state')
      )$$,
    $$values ('5000'::text, 'interrupted'::text)$$,
    'an interrupted flight is closable and receives the policy floor, never zero and never the full scale'
);
select results_eq(
    $$select delta from private.company_reputation_events
      where dispatch_id = current_setting('t0051.dispatch_b1')::uuid$$,
    array[-3],
    'an interrupted flight records a single -3 reputation event'
);

-- Immediate availability: the aircraft of the closed A1 flight takes a new
-- dispatch while its history stays in place.
set local role service_role;
select set_config(
    't0051.dispatch_a1_next',
    public.create_dispatch_draft(
        'a1000000-0000-4000-8000-000000000001',
        'a1800000-0000-4000-8000-000000000001',
        'a1300000-0000-4000-8000-000000000001',
        'LFML', 'LFBO'
    ) ->> 'dispatchId',
    true
);
reset role;

select results_eq(
    $$select state, count(*)::bigint
      from public.flight_dispatches
      where aircraft_id = 'a1300000-0000-4000-8000-000000000001'
      group by state
      order by state$$,
    $$values ('completed'::text, 1::bigint), ('draft'::text, 1::bigint)$$,
    'the closed flight stays as history while the aircraft receives a new draft'
);
select throws_ok(
    $$insert into public.flight_dispatches (company_id, aircraft_id, departure_icao, arrival_icao)
      values (
        'a1100000-0000-4000-8000-000000000001',
        'a1300000-0000-4000-8000-000000000001',
        'LFPG', 'EGLL'
      )$$,
    '23505', null::text,
    'an aircraft still admits only one open dispatch at a time'
);

select results_eq(
    $$select coalesce(sum(entries.amount_minor), 0)::bigint
      from private.financial_ledger_entries as entries
      join private.financial_ledger_subjects as subjects
        on subjects.subject_id = entries.subject_id
      where subjects.company_id = 'a1100000-0000-4000-8000-000000000001'$$,
    array[45106342::bigint],
    'the recomputed balance is exactly the opening plus the three settlements'
);
select throws_ok(
    $$update private.financial_ledger_entries
      set amount_minor = 1
      where entry_type = 'flight_settlement'$$,
    '55000', 'Financial ledger entries are append-only.',
    'a settlement entry can never be rewritten'
);
select throws_ok(
    $$update private.company_reputation_events set delta = 50$$,
    '55000', 'Reputation events are append-only.',
    'a reputation event can never be rewritten'
);
select throws_ok(
    $$delete from private.company_reputation_events$$,
    '55000', 'Reputation events are append-only.',
    'a reputation event can never be deleted'
);

insert into private.account_deletion_requests (
    id, owner_id, company_id, request_key, export_payload, export_sha256,
    requested_at, delete_after
)
values (
    'a3500000-0000-4000-8000-000000000003',
    'a3000000-0000-4000-8000-000000000003',
    'a3100000-0000-4000-8000-000000000003',
    'a3600000-0000-4000-8000-000000000003',
    '{}'::jsonb, repeat('e', 64), statement_timestamp(),
    statement_timestamp() + interval '7 days'
);

set local role service_role;
select throws_ok(
    $$select public.close_flight(
        'a3000000-0000-4000-8000-000000000003',
        'a3700000-0000-4000-8000-000000000003',
        current_setting('t0051.dispatch_p1')::uuid,
        '{"outcome":"completed","blockMinutes":30}'::jsonb
    )$$,
    '55000', 'Flight closure is unavailable.',
    'deletion pending blocks a flight closure'
);
reset role;

create function public.t0051_inject_command_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception 'Injected flight closure command failure.';
end;
$$;
create trigger t0051_inject_command_failure
before insert on private.flight_close_commands
for each row execute function public.t0051_inject_command_failure();

set local role service_role;
select throws_ok(
    $$select public.close_flight(
        'a4000000-0000-4000-8000-000000000004',
        'a4700000-0000-4000-8000-000000000004',
        current_setting('t0051.dispatch_r1')::uuid,
        '{"outcome":"completed","blockMinutes":30}'::jsonb
    )$$,
    'P0001', 'Injected flight closure command failure.',
    'injected registry failure rejects the closure'
);
reset role;

select results_eq(
    $$select
        (select state from public.flight_dispatches
         where id = current_setting('t0051.dispatch_r1')::uuid),
        (select count(*)::bigint from private.flight_reports
         where dispatch_id = current_setting('t0051.dispatch_r1')::uuid),
        (select count(*)::bigint from private.company_reputation_events
         where dispatch_id = current_setting('t0051.dispatch_r1')::uuid),
        (select count(*)::bigint from private.financial_ledger_entries as entries
         join private.financial_ledger_subjects as subjects
           on subjects.subject_id = entries.subject_id
         where subjects.company_id = 'a4100000-0000-4000-8000-000000000004'
           and entries.entry_type = 'flight_settlement')$$,
    $$values ('active'::text, 0::bigint, 0::bigint, 0::bigint)$$,
    'injected failure rolls back the state, the report, the reputation and the money'
);

drop trigger t0051_inject_command_failure on private.flight_close_commands;
drop function public.t0051_inject_command_failure();

-- Bounded informative score, read only by its owner.
insert into private.company_reputation_events (company_id, dispatch_id, delta)
values
    ('a5100000-0000-4000-8000-000000000005', current_setting('t0051.dispatch_c1')::uuid, 50),
    ('a5100000-0000-4000-8000-000000000005', current_setting('t0051.dispatch_c2')::uuid, 50),
    ('a6100000-0000-4000-8000-000000000006', current_setting('t0051.dispatch_d1')::uuid, -50),
    ('a6100000-0000-4000-8000-000000000006', current_setting('t0051.dispatch_d2')::uuid, -50);

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000001"}', true);
set local role authenticated;
select results_eq(
    'select score, event_count, schema_version from public.get_company_reputation()',
    $$values (53, 3::bigint, 1)$$,
    'owner A reads a score of 50 plus three completed flights'
);
select results_eq(
    $$select state, closed_at is not null
      from public.flight_dispatches
      order by state, id$$,
    $$values
        ('completed'::text, true),
        ('completed'::text, true),
        ('completed'::text, true),
        ('draft'::text, false)$$,
    'owner A still reads only company A dispatches, in every state'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"a2000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select results_eq(
    'select score, event_count from public.get_company_reputation()',
    $$values (47, 1::bigint)$$,
    'owner B reads its own interrupted flight score and never owner A events'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"a5000000-0000-4000-8000-000000000005"}', true);
set local role authenticated;
select results_eq(
    'select score from public.get_company_reputation()',
    array[100],
    'a score above the policy maximum is clamped to 100'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"a6000000-0000-4000-8000-000000000006"}', true);
set local role authenticated;
select results_eq(
    'select score from public.get_company_reputation()',
    array[0],
    'a score below the policy minimum is clamped to 0'
);
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
    'select score from public.get_company_reputation()',
    '42501', 'permission denied for function get_company_reputation',
    'anonymous cannot read a reputation score'
);
select throws_ok(
    'select delta from private.company_reputation_events',
    '42501', 'permission denied for schema private',
    'anonymous cannot even reach the private reputation schema'
);
reset role;

select * from finish();
rollback;
