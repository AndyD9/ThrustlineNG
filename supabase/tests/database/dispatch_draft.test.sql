begin;

select plan(22);

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('81000000-0000-4000-8000-000000000001', 'dispatch-a@thrustline.invalid', '{}', false),
    ('82000000-0000-4000-8000-000000000002', 'dispatch-b@thrustline.invalid', '{}', false),
    ('83000000-0000-4000-8000-000000000003', 'dispatch-pending@thrustline.invalid', '{}', false),
    ('84000000-0000-4000-8000-000000000004', 'dispatch-rollback@thrustline.invalid', '{}', false);

insert into public.companies (id, owner_id, name)
values
    ('81100000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', 'Dispatch Alpha Air'),
    ('82100000-0000-4000-8000-000000000002', '82000000-0000-4000-8000-000000000002', 'Dispatch Bravo Air'),
    ('83100000-0000-4000-8000-000000000003', '83000000-0000-4000-8000-000000000003', 'Dispatch Pending Air'),
    ('84100000-0000-4000-8000-000000000004', '84000000-0000-4000-8000-000000000004', 'Dispatch Rollback Air');

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor,
    currency_code, status, sold_at
)
values
    ('81200000-0000-4000-8000-000000000001', 'C172', 'DSP-C172-0001', 'Dispatch Cessna A', 1, 'EUR', 'sold', clock_timestamp()),
    ('82200000-0000-4000-8000-000000000002', 'C172', 'DSP-C172-0002', 'Dispatch Cessna B', 1, 'EUR', 'sold', clock_timestamp()),
    ('83200000-0000-4000-8000-000000000003', 'C172', 'DSP-C172-0003', 'Dispatch Cessna Pending', 1, 'EUR', 'sold', clock_timestamp()),
    ('84200000-0000-4000-8000-000000000004', 'C172', 'DSP-C172-0004', 'Dispatch Cessna Rollback', 1, 'EUR', 'sold', clock_timestamp());

insert into public.company_aircraft (
    id, company_id, offer_id, aircraft_type_code, serial_number, display_name
)
values
    ('81300000-0000-4000-8000-000000000001', '81100000-0000-4000-8000-000000000001', '81200000-0000-4000-8000-000000000001', 'C172', 'DSP-C172-0001', 'Dispatch Cessna A'),
    ('82300000-0000-4000-8000-000000000002', '82100000-0000-4000-8000-000000000002', '82200000-0000-4000-8000-000000000002', 'C172', 'DSP-C172-0002', 'Dispatch Cessna B'),
    ('83300000-0000-4000-8000-000000000003', '83100000-0000-4000-8000-000000000003', '83200000-0000-4000-8000-000000000003', 'C172', 'DSP-C172-0003', 'Dispatch Cessna Pending'),
    ('84300000-0000-4000-8000-000000000004', '84100000-0000-4000-8000-000000000004', '84200000-0000-4000-8000-000000000004', 'C172', 'DSP-C172-0004', 'Dispatch Cessna Rollback');

set local role authenticated;
select throws_ok(
    $$select public.create_dispatch_draft(
        '81000000-0000-4000-8000-000000000001',
        '81400000-0000-4000-8000-000000000001',
        '81300000-0000-4000-8000-000000000001',
        'LFPG', 'LFPO'
    )$$,
    '42501', 'permission denied for function create_dispatch_draft',
    'authenticated cannot execute the dispatch command'
);
select throws_ok(
    $$insert into public.flight_dispatches (
        company_id, aircraft_id, departure_icao, arrival_icao
      ) values (
        '81100000-0000-4000-8000-000000000001',
        '81300000-0000-4000-8000-000000000001',
        'LFPG', 'LFPO'
      )$$,
    '42501', 'permission denied for table flight_dispatches',
    'authenticated cannot forge a dispatch'
);
reset role;

set local role service_role;
select set_config(
    't0047.dispatch_response',
    public.create_dispatch_draft(
        '81000000-0000-4000-8000-000000000001',
        '81400000-0000-4000-8000-000000000001',
        '81300000-0000-4000-8000-000000000001',
        ' lfpg ', 'lfpo'
    )::text,
    true
);
reset role;

select is(current_setting('t0047.dispatch_response')::jsonb ->> 'state', 'draft', 'creation returns draft state');
select is(current_setting('t0047.dispatch_response')::jsonb ->> 'schemaVersion', '1', 'creation returns schema version 1');
select results_eq(
    $$select departure_icao, arrival_icao, state, company_id, aircraft_id
      from public.flight_dispatches$$,
    $$values (
        'LFPG'::text, 'LFPO'::text, 'draft'::text,
        '81100000-0000-4000-8000-000000000001'::uuid,
        '81300000-0000-4000-8000-000000000001'::uuid
      )$$,
    'server normalizes airports and derives company and state'
);

set local role service_role;
select is(
    public.create_dispatch_draft(
        '81000000-0000-4000-8000-000000000001',
        '81400000-0000-4000-8000-000000000001',
        '81300000-0000-4000-8000-000000000001',
        'LFPG', 'LFPO'
    )::text,
    current_setting('t0047.dispatch_response'),
    'identical dispatch creation replays with the same response'
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '81000000-0000-4000-8000-000000000001',
        '81400000-0000-4000-8000-000000000001',
        '81300000-0000-4000-8000-000000000001',
        'LFPG', 'EGLL'
    )$$,
    '22023', 'Idempotency key was already used with a different payload.',
    'dispatch idempotency payload collision is rejected'
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '81000000-0000-4000-8000-000000000001',
        '81500000-0000-4000-8000-000000000001',
        '82300000-0000-4000-8000-000000000002',
        'LFPG', 'LFPO'
    )$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'owner A cannot dispatch owner B aircraft'
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '81000000-0000-4000-8000-000000000001',
        '81600000-0000-4000-8000-000000000001',
        '81300000-0000-4000-8000-000000000001',
        'LFPG', 'EGLL'
    )$$,
    '55000', 'Aircraft already has an active dispatch.',
    'a second active draft for the same aircraft is rejected'
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '82000000-0000-4000-8000-000000000002',
        '82400000-0000-4000-8000-000000000002',
        '82300000-0000-4000-8000-000000000002',
        'ABC', 'LFPO'
    )$$,
    '22023', 'Departure and arrival must be distinct four-character ICAO codes.',
    'invalid ICAO is rejected'
);
select throws_ok(
    $$select public.create_dispatch_draft(
        '82000000-0000-4000-8000-000000000002',
        '82500000-0000-4000-8000-000000000002',
        '82300000-0000-4000-8000-000000000002',
        'LFPG', 'lfpg'
    )$$,
    '22023', 'Departure and arrival must be distinct four-character ICAO codes.',
    'identical normalized airports are rejected'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"81000000-0000-4000-8000-000000000001"}', true);
set local role authenticated;
select results_eq(
    $$select departure_icao, arrival_icao, state from public.flight_dispatches$$,
    $$values ('LFPG'::text, 'LFPO'::text, 'draft'::text)$$,
    'owner A reads only company A dispatch'
);
select throws_ok(
    $$update public.flight_dispatches set state = 'active'$$,
    '42501', 'permission denied for table flight_dispatches',
    'authenticated cannot mutate dispatch state'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"82000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select is_empty('select * from public.flight_dispatches', 'owner B cannot read owner A dispatch');
reset role;

set local role anon;
select throws_ok(
    'select * from public.flight_dispatches',
    '42501', 'permission denied for table flight_dispatches',
    'anonymous cannot read dispatches'
);
reset role;

insert into private.account_deletion_requests (
    id, owner_id, company_id, request_key, export_payload, export_sha256,
    requested_at, delete_after
)
values (
    '83400000-0000-4000-8000-000000000003',
    '83000000-0000-4000-8000-000000000003',
    '83100000-0000-4000-8000-000000000003',
    '83500000-0000-4000-8000-000000000003',
    '{}'::jsonb, repeat('d', 64), statement_timestamp(),
    statement_timestamp() + interval '7 days'
);

set local role service_role;
select throws_ok(
    $$select public.create_dispatch_draft(
        '83000000-0000-4000-8000-000000000003',
        '83600000-0000-4000-8000-000000000003',
        '83300000-0000-4000-8000-000000000003',
        'LFPG', 'LFPO'
    )$$,
    '55000', 'Dispatch creation is unavailable.',
    'deletion pending blocks dispatch creation'
);
reset role;

create function public.t0047_inject_command_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception 'Injected dispatch command failure.';
end;
$$;
create trigger t0047_inject_command_failure
before insert on private.dispatch_draft_commands
for each row execute function public.t0047_inject_command_failure();

set local role service_role;
select throws_ok(
    $$select public.create_dispatch_draft(
        '84000000-0000-4000-8000-000000000004',
        '84400000-0000-4000-8000-000000000004',
        '84300000-0000-4000-8000-000000000004',
        'LFPG', 'LFPO'
    )$$,
    'P0001', 'Injected dispatch command failure.',
    'injected registry failure rejects dispatch creation'
);
reset role;

select results_eq(
    $$select
        (select count(*) from public.flight_dispatches
         where aircraft_id = '84300000-0000-4000-8000-000000000004'),
        (select count(*) from private.dispatch_draft_commands
         where aircraft_id = '84300000-0000-4000-8000-000000000004')$$,
    $$values (0::bigint, 0::bigint)$$,
    'injected failure rolls back dispatch and command'
);
select results_eq(
    $$select count(*)::bigint from private.dispatch_draft_commands
      where owner_id = '81000000-0000-4000-8000-000000000001'$$,
    array[1::bigint],
    'successful replay retains one private command'
);
select results_eq(
    $$select count(*)::bigint from public.flight_dispatches
      where aircraft_id = '81300000-0000-4000-8000-000000000001'$$,
    array[1::bigint],
    'successful replay retains one dispatch'
);
select ok(
    (current_setting('t0047.dispatch_response')::jsonb ->> 'createdAt') is not null,
    'creation returns a server timestamp'
);
select is(
    current_setting('t0047.dispatch_response')::jsonb ->> 'aircraftId',
    '81300000-0000-4000-8000-000000000001',
    'creation returns the validated aircraft identifier'
);

select * from finish();
rollback;
