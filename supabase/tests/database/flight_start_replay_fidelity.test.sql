begin;

select plan(13);

-- T0065 — the replay of an acquired flight start restitutes the acquired
-- response, closure included. The order matters and is the point of this file:
-- the delivered T0050 scenario replays *before* close_flight, so it could never
-- fail on the case KI-024 describes. Here every replay assertion runs on a
-- dispatch that is already closed.

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('b1000000-0000-4000-8000-000000000001', 'replay-a@thrustline.invalid', '{}', false);

insert into public.companies (id, owner_id, name)
values
    ('b1100000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'Replay Alpha Air');

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor,
    currency_code, status, sold_at
)
values
    ('b1200000-0000-4000-8000-000000000001', 'C172', 'RPL-C172-0001', 'Replay Cessna A1', 1, 'EUR', 'sold', clock_timestamp()),
    ('b1200000-0000-4000-8000-000000000002', 'C172', 'RPL-C172-0002', 'Replay Cessna A2', 1, 'EUR', 'sold', clock_timestamp()),
    ('b1200000-0000-4000-8000-000000000003', 'C172', 'RPL-C172-0003', 'Replay Cessna A3', 1, 'EUR', 'sold', clock_timestamp());

insert into public.company_aircraft (
    id, company_id, offer_id, aircraft_type_code, serial_number, display_name
)
values
    ('b1300000-0000-4000-8000-000000000001', 'b1100000-0000-4000-8000-000000000001', 'b1200000-0000-4000-8000-000000000001', 'C172', 'RPL-C172-0001', 'Replay Cessna A1'),
    ('b1300000-0000-4000-8000-000000000002', 'b1100000-0000-4000-8000-000000000001', 'b1200000-0000-4000-8000-000000000002', 'C172', 'RPL-C172-0002', 'Replay Cessna A2'),
    ('b1300000-0000-4000-8000-000000000003', 'b1100000-0000-4000-8000-000000000001', 'b1200000-0000-4000-8000-000000000003', 'C172', 'RPL-C172-0003', 'Replay Cessna A3');

set local role service_role;
select public.post_company_opening_balance(
    'b1100000-0000-4000-8000-000000000001',
    'b1a00000-0000-4000-8000-000000000001', 43000000, 'EUR'
);

-- Three flights, all created and started by the delivered commands: one closed
-- as completed, one closed as interrupted, one left active.
select set_config('t0065.dispatch_closed', public.create_dispatch_draft('b1000000-0000-4000-8000-000000000001', 'b1400000-0000-4000-8000-000000000001', 'b1300000-0000-4000-8000-000000000001', 'LFBO', 'LFML') ->> 'dispatchId', true);
select set_config('t0065.dispatch_interrupted', public.create_dispatch_draft('b1000000-0000-4000-8000-000000000001', 'b1400000-0000-4000-8000-000000000002', 'b1300000-0000-4000-8000-000000000002', 'LFPG', 'LFPO') ->> 'dispatchId', true);
select set_config('t0065.dispatch_active', public.create_dispatch_draft('b1000000-0000-4000-8000-000000000001', 'b1400000-0000-4000-8000-000000000003', 'b1300000-0000-4000-8000-000000000003', 'EGLL', 'EGCC') ->> 'dispatchId', true);

select set_config(
    't0065.start_closed',
    public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000001',
        current_setting('t0065.dispatch_closed')::uuid
    )::text,
    true
);
select set_config(
    't0065.start_interrupted',
    public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000002',
        current_setting('t0065.dispatch_interrupted')::uuid
    )::text,
    true
);
select set_config(
    't0065.start_active',
    public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000003',
        current_setting('t0065.dispatch_active')::uuid
    )::text,
    true
);
reset role;

select is(
    current_setting('t0065.start_closed')::jsonb ->> 'state',
    'active',
    'the acquisition returns the active state before any closure'
);

-- Simulated elapsed flight time. The trigger owns started_at, so backdating the
-- recorded departure inside one transaction requires disabling it briefly, as the
-- delivered T0051 scenario already does.
alter table public.flight_dispatches disable trigger flight_dispatches_server_started_at;
update public.flight_dispatches
set started_at = clock_timestamp() - interval '75 minutes'
where id in (
    current_setting('t0065.dispatch_closed')::uuid,
    current_setting('t0065.dispatch_interrupted')::uuid
);
alter table public.flight_dispatches enable trigger flight_dispatches_server_started_at;

-- The closure happens here, before every replay assertion below.
set local role service_role;
select public.close_flight(
    'b1000000-0000-4000-8000-000000000001',
    'b1600000-0000-4000-8000-000000000001',
    current_setting('t0065.dispatch_closed')::uuid,
    '{"outcome":"completed","blockMinutes":70}'::jsonb
);
select public.close_flight(
    'b1000000-0000-4000-8000-000000000001',
    'b1600000-0000-4000-8000-000000000002',
    current_setting('t0065.dispatch_interrupted')::uuid,
    '{"outcome":"interrupted","blockMinutes":40}'::jsonb
);
reset role;

-- What a living read of the closed dispatch would return today: the state has
-- moved to a terminal value, while started_at is preserved because T0051
-- redefined private.set_flight_dispatch_started_at to keep it and its constraint
-- requires it to be not null for a terminal state. So exactly one of the five
-- fields drifts on this stack, not two. The restitution below does not depend on
-- that: it reads no field a closure can move or erase, so a future migration
-- changing the trigger again cannot reopen KI-024.
select results_eq(
    $$select state, started_at is not null, closed_at is not null
      from public.flight_dispatches
      where id = current_setting('t0065.dispatch_closed')::uuid$$,
    $$values ('completed'::text, true, true)$$,
    'the closed dispatch really loses the state a living read would return'
);

set local role service_role;
select set_config(
    't0065.replay_closed',
    public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000001',
        current_setting('t0065.dispatch_closed')::uuid
    )::text,
    true
);
select set_config(
    't0065.replay_interrupted',
    public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000002',
        current_setting('t0065.dispatch_interrupted')::uuid
    )::text,
    true
);
select set_config(
    't0065.replay_active',
    public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000003',
        current_setting('t0065.dispatch_active')::uuid
    )::text,
    true
);
reset role;

select is(
    current_setting('t0065.replay_closed'),
    current_setting('t0065.start_closed'),
    'a start acquired then closed as completed replays the acquired response verbatim'
);
select is(
    current_setting('t0065.replay_closed')::jsonb ->> 'state',
    'active',
    'the replayed state is the acquired active state, never the terminal one'
);
select is(
    current_setting('t0065.replay_closed')::jsonb ->> 'startedAt',
    current_setting('t0065.start_closed')::jsonb ->> 'startedAt',
    'the replayed departure instant comes from the registry, not from a living read'
);
select is(
    current_setting('t0065.replay_closed')::jsonb ->> 'aircraftId',
    'b1300000-0000-4000-8000-000000000001',
    'the replayed aircraft comes from the registry written by the granting transaction'
);
select is(
    current_setting('t0065.replay_closed')::jsonb ->> 'schemaVersion',
    '1',
    'the replayed schema version stays 1'
);
select is(
    current_setting('t0065.replay_interrupted'),
    current_setting('t0065.start_interrupted'),
    'a start acquired then closed as interrupted replays the acquired response verbatim'
);
select is(
    current_setting('t0065.replay_active'),
    current_setting('t0065.start_active'),
    'a start of a still active flight keeps replaying identically'
);

select results_eq(
    $$select
        (select count(*) from private.flight_start_commands
          where company_id = 'b1100000-0000-4000-8000-000000000001'),
        (select count(*) from public.flight_dispatches
          where company_id = 'b1100000-0000-4000-8000-000000000001'
            and state = 'active'),
        (select count(*) from private.flight_reports as reports
          join public.flight_dispatches as dispatches
            on dispatches.id = reports.dispatch_id
          where dispatches.company_id = 'b1100000-0000-4000-8000-000000000001'),
        (select count(*) from private.financial_ledger_entries as entries
          join private.financial_ledger_subjects as subjects
            on subjects.subject_id = entries.subject_id
          where subjects.company_id = 'b1100000-0000-4000-8000-000000000001')$$,
    $$values (3::bigint, 1::bigint, 2::bigint, 3::bigint)$$,
    'the three replays create no second start, no second report and no financial effect'
);

set local role service_role;
select throws_ok(
    $$select public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000001',
        current_setting('t0065.dispatch_active')::uuid
    )$$,
    '22023', 'Idempotency key was already used with a different payload.',
    'an acquired key replayed against another dispatch is still rejected after the closure'
);
select throws_ok(
    $$select public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000009',
        current_setting('t0065.dispatch_closed')::uuid
    )$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'a fresh start of a closed dispatch is still refused by the draft-only transition'
);
reset role;

set local role authenticated;
select throws_ok(
    $$select public.start_flight_from_dispatch(
        'b1000000-0000-4000-8000-000000000001',
        'b1500000-0000-4000-8000-000000000001',
        current_setting('t0065.dispatch_closed')::uuid
    )$$,
    '42501', 'permission denied for function start_flight_from_dispatch',
    'the redefined command stays out of reach of authenticated'
);
reset role;

select * from finish();
rollback;
