begin;

select plan(24);

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('71000000-0000-4000-8000-000000000001', 'purchase-a@thrustline.invalid', '{}', false),
    ('72000000-0000-4000-8000-000000000002', 'purchase-b@thrustline.invalid', '{}', false),
    ('73000000-0000-4000-8000-000000000003', 'purchase-poor@thrustline.invalid', '{}', false),
    ('74000000-0000-4000-8000-000000000004', 'purchase-rollback@thrustline.invalid', '{}', false),
    ('75000000-0000-4000-8000-000000000005', 'purchase-pending@thrustline.invalid', '{}', false);

set local role service_role;
select public.create_company_with_opening_balance(
    '71000000-0000-4000-8000-000000000001', '71100000-0000-4000-8000-000000000001',
    'Purchase Alpha Air', 43000000, 'EUR'
);
select public.create_company_with_opening_balance(
    '72000000-0000-4000-8000-000000000002', '72100000-0000-4000-8000-000000000002',
    'Purchase Bravo Air', 43000000, 'EUR'
);
select public.create_company_with_opening_balance(
    '73000000-0000-4000-8000-000000000003', '73100000-0000-4000-8000-000000000003',
    'Purchase Poor Air', 100, 'EUR'
);
select public.create_company_with_opening_balance(
    '74000000-0000-4000-8000-000000000004', '74100000-0000-4000-8000-000000000004',
    'Purchase Rollback Air', 43000000, 'EUR'
);
select public.create_company_with_opening_balance(
    '75000000-0000-4000-8000-000000000005', '75100000-0000-4000-8000-000000000005',
    'Purchase Pending Air', 43000000, 'EUR'
);
reset role;

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor, currency_code
)
values
    ('f1000000-0000-4000-8000-000000000001', 'C172', 'TEST-C172-1001', 'Test Cessna 172 A', 10000000, 'EUR'),
    ('f2000000-0000-4000-8000-000000000002', 'C172', 'TEST-C172-1002', 'Test Cessna 172 B', 10000000, 'EUR'),
    ('f3000000-0000-4000-8000-000000000003', 'C172', 'TEST-C172-1003', 'Test Cessna 172 C', 10000000, 'EUR'),
    ('f4000000-0000-4000-8000-000000000004', 'C172', 'TEST-C172-1004', 'Test Cessna 172 D', 10000000, 'EUR'),
    ('f5000000-0000-4000-8000-000000000005', 'C172', 'TEST-C172-1005', 'Test Cessna 172 E', 10000000, 'EUR');

set local role authenticated;
select throws_ok(
    $$select public.purchase_aircraft(
        '71000000-0000-4000-8000-000000000001',
        '71200000-0000-4000-8000-000000000001',
        'f1000000-0000-4000-8000-000000000001'
    )$$,
    '42501', 'permission denied for function purchase_aircraft',
    'authenticated cannot execute the purchase command'
);
select throws_ok(
    $$insert into public.company_aircraft (
        company_id, offer_id, aircraft_type_code, serial_number, display_name
      ) values (
        'a0000000-0000-4000-8000-000000000001',
        'f1000000-0000-4000-8000-000000000001',
        'C172', 'FORGED-C172-1', 'Forged Cessna'
      )$$,
    '42501', 'permission denied for table company_aircraft',
    'authenticated cannot forge aircraft ownership'
);
reset role;

set local role service_role;
select set_config(
    't0029.purchase_response',
    public.purchase_aircraft(
        '71000000-0000-4000-8000-000000000001',
        '71200000-0000-4000-8000-000000000001',
        'f1000000-0000-4000-8000-000000000001'
    )::text,
    true
);
reset role;

select is(current_setting('t0029.purchase_response')::jsonb ->> 'state', 'owned', 'purchase returns owned state');
select is(current_setting('t0029.purchase_response')::jsonb ->> 'schemaVersion', '1', 'purchase returns schema version 1');
select results_eq(
    $$select count(*)::bigint from public.company_aircraft
      where offer_id = 'f1000000-0000-4000-8000-000000000001'$$,
    array[1::bigint], 'purchase creates one aircraft'
);
select results_eq(
    $$select sequence_number, entry_type, amount_minor, currency_code
      from private.financial_ledger_entries as entries
      join private.financial_ledger_subjects as subjects using (subject_id)
      join public.companies as companies on companies.id = subjects.company_id
      where companies.owner_id = '71000000-0000-4000-8000-000000000001'
      order by sequence_number$$,
    $$values
        (1::bigint, 'opening_balance'::text, 43000000::bigint, 'EUR'::text),
        (2::bigint, 'aircraft_purchase'::text, -10000000::bigint, 'EUR'::text)$$,
    'purchase appends exactly one negative ledger entry'
);
select results_eq(
    $$select status, sold_at is not null, seller_kind from public.aircraft_purchase_offers
      where id = 'f1000000-0000-4000-8000-000000000001'$$,
    $$values ('sold'::text, true, 'system'::text)$$,
    'purchase consumes the system-owned unit offer'
);

set local role service_role;
select is(
    public.purchase_aircraft(
        '71000000-0000-4000-8000-000000000001',
        '71200000-0000-4000-8000-000000000001',
        'f1000000-0000-4000-8000-000000000001'
    )::text,
    current_setting('t0029.purchase_response'),
    'identical purchase replays with the same response'
);
select throws_ok(
    $$select public.purchase_aircraft(
        '71000000-0000-4000-8000-000000000001',
        '71200000-0000-4000-8000-000000000001',
        'f2000000-0000-4000-8000-000000000002'
    )$$,
    '22023', 'Idempotency key was already used with a different payload.',
    'purchase idempotency collision is rejected'
);
select throws_ok(
    $$select public.purchase_aircraft(
        '72000000-0000-4000-8000-000000000002',
        '72200000-0000-4000-8000-000000000002',
        'f1000000-0000-4000-8000-000000000001'
    )$$,
    '55000', 'Aircraft offer is unavailable.',
    'a sold unit offer cannot be bought by another owner'
);
select throws_ok(
    $$select public.purchase_aircraft(
        '73000000-0000-4000-8000-000000000003',
        '73200000-0000-4000-8000-000000000003',
        'f3000000-0000-4000-8000-000000000003'
    )$$,
    '23514', 'Company balance is insufficient for this aircraft.',
    'insufficient balance is rejected'
);
reset role;

select results_eq(
    $$select
        (select count(*) from public.company_aircraft where offer_id = 'f3000000-0000-4000-8000-000000000003'),
        (select count(*) from private.aircraft_purchase_commands where offer_id = 'f3000000-0000-4000-8000-000000000003'),
        (select count(*) from private.financial_ledger_entries where idempotency_key = '73200000-0000-4000-8000-000000000003')$$,
    $$values (0::bigint, 0::bigint, 0::bigint)$$,
    'insufficient balance leaves no partial state'
);

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"71000000-0000-4000-8000-000000000001"}', true);
set local role authenticated;
select results_eq(
    $$select offer_id, acquisition_kind from public.get_company_aircraft()$$,
    $$values ('f1000000-0000-4000-8000-000000000001'::uuid, 'purchase'::text)$$,
    'owner A reads the purchased aircraft'
);
select results_eq(
    $$select count(*)::bigint from public.aircraft_purchase_offers
      where id = 'f1000000-0000-4000-8000-000000000001'$$,
    array[0::bigint], 'sold offers disappear from authenticated catalogue reads'
);
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"72000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select is_empty('select * from public.get_company_aircraft()', 'owner B cannot read owner A aircraft');
select throws_ok(
    $$update public.aircraft_purchase_offers set price_minor = 1$$,
    '42501', 'permission denied for table aircraft_purchase_offers',
    'authenticated cannot forge an offer price'
);
select throws_ok(
    $$delete from public.company_aircraft$$,
    '42501', 'permission denied for table company_aircraft',
    'authenticated cannot delete aircraft ownership'
);
reset role;

set local role anon;
select throws_ok(
    'select * from public.get_company_aircraft()',
    '42501', 'permission denied for function get_company_aircraft',
    'anonymous cannot read company aircraft'
);
reset role;

insert into private.account_deletion_requests (
    id, owner_id, company_id, request_key, export_payload, export_sha256,
    requested_at, delete_after
)
select
    '75200000-0000-4000-8000-000000000005', owner_id, id,
    '75300000-0000-4000-8000-000000000005', '{}'::jsonb, repeat('d', 64),
    statement_timestamp(), statement_timestamp() + interval '7 days'
from public.companies
where owner_id = '75000000-0000-4000-8000-000000000005';

set local role service_role;
select throws_ok(
    $$select public.purchase_aircraft(
        '75000000-0000-4000-8000-000000000005',
        '75400000-0000-4000-8000-000000000005',
        'f5000000-0000-4000-8000-000000000005'
    )$$,
    '55000', 'Aircraft purchase is unavailable.',
    'deletion pending blocks aircraft purchase'
);
reset role;

create function public.t0029_inject_ledger_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.entry_type = 'aircraft_purchase' then
        raise exception 'Injected aircraft purchase failure.';
    end if;
    return new;
end;
$$;
create trigger t0029_inject_ledger_failure
before insert on private.financial_ledger_entries
for each row execute function public.t0029_inject_ledger_failure();

set local role service_role;
select throws_ok(
    $$select public.purchase_aircraft(
        '74000000-0000-4000-8000-000000000004',
        '74200000-0000-4000-8000-000000000004',
        'f4000000-0000-4000-8000-000000000004'
    )$$,
    'P0001', 'Injected aircraft purchase failure.',
    'injected debit failure rejects the purchase'
);
reset role;

select results_eq(
    $$select
        (select count(*) from public.company_aircraft where offer_id = 'f4000000-0000-4000-8000-000000000004'),
        (select count(*) from private.aircraft_purchase_commands where offer_id = 'f4000000-0000-4000-8000-000000000004'),
        (select count(*) from private.financial_ledger_entries where idempotency_key = '74200000-0000-4000-8000-000000000004'),
        (select status from public.aircraft_purchase_offers where id = 'f4000000-0000-4000-8000-000000000004')$$,
    $$values (0::bigint, 0::bigint, 0::bigint, 'available'::text)$$,
    'injected failure rolls back ownership, command, debit and offer state'
);

select results_eq(
    $$select count(*)::bigint from private.aircraft_purchase_commands
      where owner_id = '71000000-0000-4000-8000-000000000001'$$,
    array[1::bigint], 'successful replay retains one private command'
);
select results_eq(
    $$select count(*)::bigint from private.financial_ledger_entries
      where idempotency_key = '71200000-0000-4000-8000-000000000001'$$,
    array[1::bigint], 'successful replay retains one debit'
);
select results_eq(
    $$select amount_minor from public.get_company_ledger() where false$$,
    array[]::bigint[], 'unauthenticated owner context exposes no ledger rows'
);

select * from finish();
rollback;
