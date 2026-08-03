begin;

select plan(24);

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('91000000-0000-4000-8000-000000000001', 'flight-a@thrustline.invalid', '{}', false),
    ('92000000-0000-4000-8000-000000000002', 'flight-b@thrustline.invalid', '{}', false),
    ('93000000-0000-4000-8000-000000000003', 'flight-pending@thrustline.invalid', '{}', false),
    ('94000000-0000-4000-8000-000000000004', 'flight-rollback@thrustline.invalid', '{}', false);

insert into public.companies (id, owner_id, name)
values
    ('91100000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', 'Flight Alpha Air'),
    ('92100000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000002', 'Flight Bravo Air'),
    ('93100000-0000-4000-8000-000000000003', '93000000-0000-4000-8000-000000000003', 'Flight Pending Air'),
    ('94100000-0000-4000-8000-000000000004', '94000000-0000-4000-8000-000000000004', 'Flight Rollback Air');

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor,
    currency_code, status, sold_at
)
values
    ('91200000-0000-4000-8000-000000000001', 'C172', 'FLT-C172-0001', 'Flight Cessna A1', 1, 'EUR', 'sold', clock_timestamp()),
    ('91500000-0000-4000-8000-000000000001', 'C172', 'FLT-C172-0005', 'Flight Cessna A2', 1, 'EUR', 'sold', clock_timestamp()),
    ('92200000-0000-4000-8000-000000000002', 'C172', 'FLT-C172-0002', 'Flight Cessna B', 1, 'EUR', 'sold', clock_timestamp()),
    ('93200000-0000-4000-8000-000000000003', 'C172', 'FLT-C172-0003', 'Flight Cessna Pending', 1, 'EUR', 'sold', clock_timestamp()),
    ('94200000-0000-4000-8000-000000000004', 'C172', 'FLT-C172-0004', 'Flight Cessna Rollback', 1, 'EUR', 'sold', clock_timestamp());

insert into public.company_aircraft (
    id, company_id, offer_id, aircraft_type_code, serial_number, display_name
)
values
    ('91300000-0000-4000-8000-000000000001', '91100000-0000-4000-8000-000000000001', '91200000-0000-4000-8000-000000000001', 'C172', 'FLT-C172-0001', 'Flight Cessna A1'),
    ('91600000-0000-4000-8000-000000000001', '91100000-0000-4000-8000-000000000001', '91500000-0000-4000-8000-000000000001', 'C172', 'FLT-C172-0005', 'Flight Cessna A2'),
    ('92300000-0000-4000-8000-000000000002', '92100000-0000-4000-8000-000000000002', '92200000-0000-4000-8000-000000000002', 'C172', 'FLT-C172-0002', 'Flight Cessna B'),
    ('93300000-0000-4000-8000-000000000003', '93100000-0000-4000-8000-000000000003', '93200000-0000-4000-8000-000000000003', 'C172', 'FLT-C172-0003', 'Flight Cessna Pending'),
    ('94300000-0000-4000-8000-000000000004', '94100000-0000-4000-8000-000000000004', '94200000-0000-4000-8000-000000000004', 'C172', 'FLT-C172-0004', 'Flight Cessna Rollback');

set local role service_role;
select set_config(
    't0050.dispatch_a1',
    public.create_dispatch_draft(
        '91000000-0000-4000-8000-000000000001',
        '91400000-0000-4000-8000-000000000001',
        '91300000-0000-4000-8000-000000000001',
        'LFPG', 'LFPO'
    ) ->> 'dispatchId',
    true
);
select set_config(
    't0050.dispatch_a2',
    public.create_dispatch_draft(
        '91000000-0000-4000-8000-000000000001',
        '91700000-0000-4000-8000-000000000001',
        '91600000-0000-4000-8000-000000000001',
        'LFPG', 'EGLL'
    ) ->> 'dispatchId',
    true
);
select set_config(
    't0050.dispatch_b',
    public.create_dispatch_draft(
        '92000000-0000-4000-8000-000000000002',
        '92400000-0000-4000-8000-000000000002',
        '92300000-0000-4000-8000-000000000002',
        'LFBO', 'LFML'
    ) ->> 'dispatchId',
    true
);
select set_config(
    't0050.dispatch_pending',
    public.create_dispatch_draft(
        '93000000-0000-4000-8000-000000000003',
        '93400000-0000-4000-8000-000000000003',
        '93300000-0000-4000-8000-000000000003',
        'LFPG', 'LFBO'
    ) ->> 'dispatchId',
    true
);
select set_config(
    't0050.dispatch_rollback',
    public.create_dispatch_draft(
        '94000000-0000-4000-8000-000000000004',
        '94400000-0000-4000-8000-000000000004',
        '94300000-0000-4000-8000-000000000004',
        'LFPO', 'LFML'
    ) ->> 'dispatchId',
    true
);
reset role;

set local role authenticated;
select throws_ok(
    $$select public.start_flight_from_dispatch(
        '91000000-0000-4000-8000-000000000001',
        '91800000-0000-4000-8000-000000000001',
        current_setting('t0050.dispatch_a1')::uuid
    )$$,
    '42501', 'permission denied for function start_flight_from_dispatch',
    'authenticated cannot execute the flight start command'
);
select throws_ok(
    $$update public.flight_dispatches
      set state = 'active', started_at = clock_timestamp()$$,
    '42501', 'permission denied for table flight_dispatches',
    'authenticated cannot forge a flight state or departure time'
);
reset role;

set local role service_role;
select set_config(
    't0050.start_response',
    public.start_flight_from_dispatch(
        '91000000-0000-4000-8000-000000000001',
        '91800000-0000-4000-8000-000000000001',
        current_setting('t0050.dispatch_a1')::uuid
    )::text,
    true
);
reset role;

select is(current_setting('t0050.start_response')::jsonb ->> 'state', 'active', 'the start returns the active state');
select is(current_setting('t0050.start_response')::jsonb ->> 'schemaVersion', '1', 'the start returns schema version 1');
select ok(
    (current_setting('t0050.start_response')::jsonb ->> 'startedAt') is not null,
    'the start returns a server departure timestamp'
);
select is(
    current_setting('t0050.start_response')::jsonb ->> 'dispatchId',
    current_setting('t0050.dispatch_a1'),
    'the start returns the requested dispatch'
);
select is(
    current_setting('t0050.start_response')::jsonb ->> 'aircraftId',
    '91300000-0000-4000-8000-000000000001',
    'the server derives the aircraft from the dispatch'
);
select results_eq(
    $$select state, company_id, aircraft_id, started_at is not null
      from public.flight_dispatches
      where id = current_setting('t0050.dispatch_a1')::uuid$$,
    $$values (
        'active'::text,
        '91100000-0000-4000-8000-000000000001'::uuid,
        '91300000-0000-4000-8000-000000000001'::uuid,
        true
      )$$,
    'exactly one owned draft becomes one server-timed active flight'
);

set local role service_role;
select is(
    public.start_flight_from_dispatch(
        '91000000-0000-4000-8000-000000000001',
        '91800000-0000-4000-8000-000000000001',
        current_setting('t0050.dispatch_a1')::uuid
    )::text,
    current_setting('t0050.start_response'),
    'identical flight start replays with the same response'
);
select throws_ok(
    $$select public.start_flight_from_dispatch(
        '91000000-0000-4000-8000-000000000001',
        '91800000-0000-4000-8000-000000000001',
        current_setting('t0050.dispatch_a2')::uuid
    )$$,
    '22023', 'Idempotency key was already used with a different payload.',
    'flight start idempotency payload collision is rejected'
);
select throws_ok(
    $$select public.start_flight_from_dispatch(
        '91000000-0000-4000-8000-000000000001',
        '91b00000-0000-4000-8000-000000000001',
        current_setting('t0050.dispatch_b')::uuid
    )$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'owner A cannot start owner B dispatch'
);
select throws_ok(
    $$select public.start_flight_from_dispatch(
        '91000000-0000-4000-8000-000000000001',
        '91900000-0000-4000-8000-000000000001',
        current_setting('t0050.dispatch_a1')::uuid
    )$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'a second start of the same dispatch is rejected'
);
select throws_ok(
    $$select public.start_flight_from_dispatch(
        '91000000-0000-4000-8000-000000000001',
        '91a00000-0000-4000-8000-000000000001',
        '91c00000-0000-4000-8000-000000000001'
    )$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'an unknown dispatch fails closed with the same message'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"91000000-0000-4000-8000-000000000001"}', true);
set local role authenticated;
select results_eq(
    $$select state, started_at is not null
      from public.flight_dispatches
      order by state$$,
    $$values ('active'::text, true), ('draft'::text, false)$$,
    'owner A reads only company A dispatches with their server flight state'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"92000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select results_eq(
    $$select state, started_at is not null from public.flight_dispatches$$,
    $$values ('draft'::text, false)$$,
    'owner B cannot read owner A active flight'
);
reset role;

set local role anon;
select throws_ok(
    'select state, started_at from public.flight_dispatches',
    '42501', 'permission denied for table flight_dispatches',
    'anonymous cannot read a flight state'
);
reset role;

select throws_ok(
    $$update public.flight_dispatches
      set state = 'completed'
      where id = current_setting('t0050.dispatch_a2')::uuid$$,
    '23514', null::text,
    'no state outside draft and active is accepted'
);

update public.flight_dispatches
set started_at = '1999-01-01T00:00:00Z'
where id = current_setting('t0050.dispatch_a1')::uuid;
select is(
    (select started_at from public.flight_dispatches
     where id = current_setting('t0050.dispatch_a1')::uuid),
    (current_setting('t0050.start_response')::jsonb ->> 'startedAt')::timestamptz,
    'a forged departure time cannot replace the recorded server time'
);

update public.flight_dispatches
set started_at = clock_timestamp()
where id = current_setting('t0050.dispatch_a2')::uuid;
select ok(
    (select started_at is null from public.flight_dispatches
     where id = current_setting('t0050.dispatch_a2')::uuid),
    'a draft cannot carry a departure time'
);

insert into private.account_deletion_requests (
    id, owner_id, company_id, request_key, export_payload, export_sha256,
    requested_at, delete_after
)
values (
    '93500000-0000-4000-8000-000000000003',
    '93000000-0000-4000-8000-000000000003',
    '93100000-0000-4000-8000-000000000003',
    '93600000-0000-4000-8000-000000000003',
    '{}'::jsonb, repeat('d', 64), statement_timestamp(),
    statement_timestamp() + interval '7 days'
);

set local role service_role;
select throws_ok(
    $$select public.start_flight_from_dispatch(
        '93000000-0000-4000-8000-000000000003',
        '93700000-0000-4000-8000-000000000003',
        current_setting('t0050.dispatch_pending')::uuid
    )$$,
    '55000', 'Flight start is unavailable.',
    'deletion pending blocks a flight start'
);
reset role;

create function public.t0050_inject_command_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception 'Injected flight start command failure.';
end;
$$;
create trigger t0050_inject_command_failure
before insert on private.flight_start_commands
for each row execute function public.t0050_inject_command_failure();

set local role service_role;
select throws_ok(
    $$select public.start_flight_from_dispatch(
        '94000000-0000-4000-8000-000000000004',
        '94500000-0000-4000-8000-000000000004',
        current_setting('t0050.dispatch_rollback')::uuid
    )$$,
    'P0001', 'Injected flight start command failure.',
    'injected registry failure rejects the flight start'
);
reset role;

select results_eq(
    $$select state, started_at is not null,
        (select count(*) from private.flight_start_commands
         where dispatch_id = current_setting('t0050.dispatch_rollback')::uuid)
      from public.flight_dispatches
      where id = current_setting('t0050.dispatch_rollback')::uuid$$,
    $$values ('draft'::text, false, 0::bigint)$$,
    'injected failure rolls back the flight state, its time and the command'
);
select results_eq(
    $$select count(*)::bigint,
        count(distinct dispatch_id)::bigint,
        count(*) filter (
            where commands.started_at = (
                select dispatches.started_at
                from public.flight_dispatches as dispatches
                where dispatches.id = commands.dispatch_id
            )
        )::bigint
      from private.flight_start_commands as commands
      where commands.owner_id = '91000000-0000-4000-8000-000000000001'$$,
    $$values (1::bigint, 1::bigint, 1::bigint)$$,
    'a replayed start retains one command bound to the recorded departure time'
);
select results_eq(
    $$select count(*)::bigint from public.flight_dispatches
      where state = 'active'
        and company_id in (
            '91100000-0000-4000-8000-000000000001',
            '92100000-0000-4000-8000-000000000002',
            '93100000-0000-4000-8000-000000000003',
            '94100000-0000-4000-8000-000000000004'
        )$$,
    array[1::bigint],
    'the whole scenario leaves exactly one active flight'
);

select * from finish();
rollback;
