begin;

select plan(33);

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('81000000-0000-4000-8000-000000000001', 'lease-a@thrustline.invalid', '{}', false),
    ('82000000-0000-4000-8000-000000000002', 'lease-b@thrustline.invalid', '{}', false),
    ('83000000-0000-4000-8000-000000000003', 'lease-poor@thrustline.invalid', '{}', false),
    ('84000000-0000-4000-8000-000000000004', 'lease-grace@thrustline.invalid', '{}', false),
    ('85000000-0000-4000-8000-000000000005', 'lease-end@thrustline.invalid', '{}', false),
    ('86000000-0000-4000-8000-000000000006', 'lease-rollback@thrustline.invalid', '{}', false),
    ('87000000-0000-4000-8000-000000000007', 'lease-pending@thrustline.invalid', '{}', false);

set local role service_role;
select public.create_company_with_opening_balance('81000000-0000-4000-8000-000000000001', '81100000-0000-4000-8000-000000000001', 'Lease Alpha Air', 1000000, 'EUR');
select public.create_company_with_opening_balance('82000000-0000-4000-8000-000000000002', '82100000-0000-4000-8000-000000000002', 'Lease Bravo Air', 1000000, 'EUR');
select public.create_company_with_opening_balance('83000000-0000-4000-8000-000000000003', '83100000-0000-4000-8000-000000000003', 'Lease Poor Air', 49, 'EUR');
select public.create_company_with_opening_balance('84000000-0000-4000-8000-000000000004', '84100000-0000-4000-8000-000000000004', 'Lease Grace Air', 50, 'EUR');
select public.create_company_with_opening_balance('85000000-0000-4000-8000-000000000005', '85100000-0000-4000-8000-000000000005', 'Lease End Air', 2000, 'EUR');
select public.create_company_with_opening_balance('86000000-0000-4000-8000-000000000006', '86100000-0000-4000-8000-000000000006', 'Lease Rollback Air', 1000000, 'EUR');
select public.create_company_with_opening_balance('87000000-0000-4000-8000-000000000007', '87100000-0000-4000-8000-000000000007', 'Lease Pending Air', 1000000, 'EUR');
reset role;

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor, currency_code,
    offer_kind, terms_version, duration_days, cadence_hours, rent_minor,
    initial_payment_minor, grace_hours, voluntary_termination,
    termination_penalty_minor, usable_during_grace
)
values
    ('e8000000-0000-4000-8000-000000000008', 'C172', 'LEASE-C172-1001', 'Lease Cessna A', 10000, 'EUR', 'lease', 1, 30, 24, 50, 50, 48, true, 0, true),
    ('e9000000-0000-4000-8000-000000000009', 'C172', 'LEASE-C172-1002', 'Lease Cessna B', 10000, 'EUR', 'lease', 1, 30, 24, 50, 50, 48, true, 0, true),
    ('e3000000-0000-4000-8000-000000000003', 'C172', 'LEASE-C172-1003', 'Lease Cessna Poor', 10000, 'EUR', 'lease', 1, 30, 24, 50, 50, 48, true, 0, true),
    ('e4000000-0000-4000-8000-000000000004', 'C172', 'LEASE-C172-1004', 'Lease Cessna Grace', 10000, 'EUR', 'lease', 1, 30, 24, 50, 50, 48, true, 0, true),
    ('e5000000-0000-4000-8000-000000000005', 'C172', 'LEASE-C172-1005', 'Lease Cessna End', 10000, 'EUR', 'lease', 1, 30, 24, 50, 50, 48, true, 0, true),
    ('e6000000-0000-4000-8000-000000000006', 'C172', 'LEASE-C172-1006', 'Lease Cessna Rollback', 10000, 'EUR', 'lease', 1, 30, 24, 50, 50, 48, true, 0, true),
    ('e7000000-0000-4000-8000-000000000007', 'C172', 'LEASE-C172-1007', 'Lease Cessna Pending', 10000, 'EUR', 'lease', 1, 30, 24, 50, 50, 48, true, 0, true);

set local role authenticated;
select throws_ok(
    $$select public.lease_aircraft('81000000-0000-4000-8000-000000000001', '81200000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000008')$$,
    '42501', 'permission denied for function lease_aircraft', 'authenticated cannot create a lease'
);
select throws_ok(
    $$select public.process_aircraft_lease('e8000000-0000-4000-8000-000000000008', '81300000-0000-4000-8000-000000000001', clock_timestamp())$$,
    '42501', 'permission denied for function process_aircraft_lease', 'authenticated cannot provide authoritative time'
);
reset role;

set local role service_role;
select set_config('t0032.creation', public.lease_aircraft(
    '81000000-0000-4000-8000-000000000001', '81200000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000008'
)::text, true);
reset role;

select is(current_setting('t0032.creation')::jsonb ->> 'state', 'active', 'lease activates atomically');
select results_eq(
    $$select terms_version, duration_days, cadence_hours, rent_minor, grace_hours,
             initial_payment_minor, voluntary_termination, termination_penalty_minor, usable_during_grace
      from public.aircraft_lease_contracts where id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid$$,
    $$values (1, 30, 24, 50::bigint, 48, 50::bigint, true, 0::bigint, true)$$,
    'contract snapshots the approved versioned terms'
);
select results_eq(
    $$select installment_number, state, amount_minor, ledger_entry_id is not null
      from public.aircraft_lease_installments where contract_id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid$$,
    $$values (1, 'paid'::text, 50::bigint, true)$$,
    'first rent is paid at activation without deposit'
);
select results_eq(
    $$select acquisition_kind, is_usable from public.company_aircraft where id = (current_setting('t0032.creation')::jsonb ->> 'aircraftId')::uuid$$,
    $$values ('lease'::text, true)$$, 'leased aircraft is usable'
);
select results_eq(
    $$select entry_type, amount_minor from private.financial_ledger_entries where id = (current_setting('t0032.creation')::jsonb ->> 'ledgerEntryId')::uuid$$,
    $$values ('aircraft_lease_rent'::text, (-50)::bigint)$$, 'activation appends one rent debit'
);

set local role service_role;
select is(public.lease_aircraft(
    '81000000-0000-4000-8000-000000000001', '81200000-0000-4000-8000-000000000001', 'e8000000-0000-4000-8000-000000000008'
)::text, current_setting('t0032.creation'), 'creation replay returns the same response');
select throws_ok(
    $$select public.lease_aircraft('81000000-0000-4000-8000-000000000001', '81200000-0000-4000-8000-000000000001', 'e9000000-0000-4000-8000-000000000009')$$,
    '22023', 'Idempotency key was already used with a different payload.', 'creation collision is rejected'
);
select throws_ok(
    $$select public.lease_aircraft('82000000-0000-4000-8000-000000000002', '82200000-0000-4000-8000-000000000002', 'e8000000-0000-4000-8000-000000000008')$$,
    '55000', 'Aircraft lease offer is unavailable.', 'one unit offer cannot be acquired twice'
);
select throws_ok(
    $$select public.lease_aircraft('83000000-0000-4000-8000-000000000003', '83200000-0000-4000-8000-000000000003', 'e3000000-0000-4000-8000-000000000003')$$,
    '23514', 'Company balance is insufficient for this aircraft lease.', 'insufficient activation balance fails closed'
);
reset role;

select results_eq(
    $$select (select count(*) from public.company_aircraft where offer_id = 'e3000000-0000-4000-8000-000000000003'),
             (select count(*) from public.aircraft_lease_contracts where offer_id = 'e3000000-0000-4000-8000-000000000003')$$,
    $$values (0::bigint, 0::bigint)$$, 'failed activation leaves no partial aircraft or contract'
);

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"81000000-0000-4000-8000-000000000001"}', true);
set local role authenticated;
select results_eq('select state from public.aircraft_lease_contracts', $$values ('active'::text)$$,
    'owner reads its contract');
select results_eq('select installment_number from public.aircraft_lease_installments', $$values (1)$$,
    'owner reads its installment');
select throws_ok('update public.aircraft_lease_contracts set state = ''terminated''',
    '42501', 'permission denied for table aircraft_lease_contracts', 'owner cannot mutate contract state');
reset role;

select set_config('request.jwt.claims', '{"role":"authenticated","sub":"82000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select is_empty('select * from public.aircraft_lease_contracts', 'owner B cannot read owner A contract');
select is_empty('select * from public.aircraft_lease_installments', 'owner B cannot read owner A installments');
reset role;

set local role anon;
select throws_ok('select * from public.aircraft_lease_contracts', '42501', 'permission denied for table aircraft_lease_contracts',
    'anonymous cannot read contracts');
reset role;

set local role service_role;
select set_config('t0032.deleted_contract', public.lease_aircraft(
    '82000000-0000-4000-8000-000000000002', '82200000-0000-4000-8000-000000000002', 'e9000000-0000-4000-8000-000000000009'
)::text, true);
reset role;
delete from public.companies where owner_id = '82000000-0000-4000-8000-000000000002';
select results_eq(
    $$select contracts.state, contracts.company_id, contracts.aircraft_id,
             (select count(*) from public.company_aircraft where company_id is null)
      from public.aircraft_lease_contracts contracts
      where contracts.id = (current_setting('t0032.deleted_contract')::jsonb ->> 'contractId')::uuid$$,
    $$values ('terminated'::text, null::uuid, null::uuid, 0::bigint)$$,
    'company deletion terminates and detaches the lease without retaining aircraft'
);

select set_config('t0032.active_at', (select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid,
    '81300000-0000-4000-8000-000000000001', current_setting('t0032.active_at')::timestamptz + interval '23 hours 59 minutes'
);
reset role;
select results_eq(
    $$select count(*)::bigint from public.aircraft_lease_installments where contract_id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid$$,
    array[1::bigint], 'no installment is due before the 24-hour boundary'
);

set local role service_role;
select set_config('t0032.due_response', public.process_aircraft_lease(
    (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid,
    '81400000-0000-4000-8000-000000000001', current_setting('t0032.active_at')::timestamptz + interval '24 hours'
)::text, true);
select is(public.process_aircraft_lease(
    (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid,
    '81400000-0000-4000-8000-000000000001', current_setting('t0032.active_at')::timestamptz + interval '24 hours'
)::text, current_setting('t0032.due_response'), 'temporal replay returns the same response');
reset role;
select results_eq(
    $$select installment_number, state from public.aircraft_lease_installments
      where contract_id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid order by installment_number$$,
    $$values (1, 'paid'::text), (2, 'paid'::text)$$, 'boundary processing materializes one due rent once'
);

set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid,
    '81500000-0000-4000-8000-000000000001', current_setting('t0032.active_at')::timestamptz + interval '72 hours'
);
reset role;
select results_eq(
    $$select array_agg(installment_number order by installment_number) from public.aircraft_lease_installments
      where contract_id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid$$,
    $$values (array[1,2,3,4])$$, 'catch-up materializes missed rents in deterministic order'
);

set local role service_role;
select set_config('t0032.grace', public.lease_aircraft(
    '84000000-0000-4000-8000-000000000004', '84200000-0000-4000-8000-000000000004', 'e4000000-0000-4000-8000-000000000004'
)::text, true);
reset role;
select set_config('t0032.grace_at', (select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0032.grace')::jsonb ->> 'contractId')::uuid), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0032.grace')::jsonb ->> 'contractId')::uuid, '84300000-0000-4000-8000-000000000004',
    current_setting('t0032.grace_at')::timestamptz + interval '24 hours'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable from public.aircraft_lease_contracts contracts
      join public.company_aircraft aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0032.grace')::jsonb ->> 'contractId')::uuid$$,
    $$values ('grace'::text, true)$$, 'insufficient rent enters grace while aircraft remains usable'
);

set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0032.grace')::jsonb ->> 'contractId')::uuid, '84400000-0000-4000-8000-000000000004',
    current_setting('t0032.grace_at')::timestamptz + interval '72 hours'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable from public.aircraft_lease_contracts contracts
      join public.company_aircraft aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0032.grace')::jsonb ->> 'contractId')::uuid$$,
    $$values ('defaulted'::text, false)$$, '48-hour grace boundary defaults and removes usage'
);

set local role service_role;
select set_config('t0032.end', public.lease_aircraft(
    '85000000-0000-4000-8000-000000000005', '85200000-0000-4000-8000-000000000005', 'e5000000-0000-4000-8000-000000000005'
)::text, true);
reset role;
select set_config('t0032.end_at', (select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0032.end')::jsonb ->> 'contractId')::uuid), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0032.end')::jsonb ->> 'contractId')::uuid, '85300000-0000-4000-8000-000000000005',
    current_setting('t0032.end_at')::timestamptz + interval '30 days'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable, count(installments.id)
      from public.aircraft_lease_contracts contracts
      join public.company_aircraft aircraft on aircraft.id = contracts.aircraft_id
      join public.aircraft_lease_installments installments on installments.contract_id = contracts.id
      where contracts.id = (current_setting('t0032.end')::jsonb ->> 'contractId')::uuid
      group by contracts.state, aircraft.is_usable$$,
    $$values ('expired'::text, false, 30::bigint)$$, 'paid contract expires after 30 days and removes usage'
);

set local role service_role;
select set_config('t0032.termination', public.terminate_aircraft_lease(
    '81000000-0000-4000-8000-000000000001', (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid,
    '81600000-0000-4000-8000-000000000001'
)::text, true);
select is(public.terminate_aircraft_lease(
    '81000000-0000-4000-8000-000000000001', (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid,
    '81600000-0000-4000-8000-000000000001'
)::text, current_setting('t0032.termination'), 'termination replay is idempotent');
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable from public.aircraft_lease_contracts contracts
      join public.company_aircraft aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid$$,
    $$values ('terminated'::text, false)$$, 'voluntary termination is immediate and removes usage'
);

insert into private.account_deletion_requests (
    id, owner_id, company_id, request_key, export_payload, export_sha256, requested_at, delete_after
)
select '87200000-0000-4000-8000-000000000007', owner_id, id,
    '87300000-0000-4000-8000-000000000007', '{}'::jsonb, repeat('d', 64), statement_timestamp(), statement_timestamp() + interval '7 days'
from public.companies where owner_id = '87000000-0000-4000-8000-000000000007';
set local role service_role;
select throws_ok(
    $$select public.lease_aircraft('87000000-0000-4000-8000-000000000007', '87400000-0000-4000-8000-000000000007', 'e7000000-0000-4000-8000-000000000007')$$,
    '55000', 'Aircraft lease is unavailable.', 'deletion pending blocks lease creation'
);
reset role;

create function public.t0032_inject_ledger_failure() returns trigger language plpgsql set search_path = '' as $$
begin
    if new.entry_type = 'aircraft_lease_rent' then raise exception 'Injected aircraft lease failure.'; end if;
    return new;
end;
$$;
create trigger t0032_inject_ledger_failure before insert on private.financial_ledger_entries
for each row execute function public.t0032_inject_ledger_failure();
set local role service_role;
select throws_ok(
    $$select public.lease_aircraft('86000000-0000-4000-8000-000000000006', '86200000-0000-4000-8000-000000000006', 'e6000000-0000-4000-8000-000000000006')$$,
    'P0001', 'Injected aircraft lease failure.', 'injected debit failure rejects activation'
);
reset role;
select results_eq(
    $$select (select count(*) from public.company_aircraft where offer_id = 'e6000000-0000-4000-8000-000000000006'),
             (select count(*) from public.aircraft_lease_contracts where offer_id = 'e6000000-0000-4000-8000-000000000006'),
             (select status from public.aircraft_purchase_offers where id = 'e6000000-0000-4000-8000-000000000006')$$,
    $$values (0::bigint, 0::bigint, 'available'::text)$$, 'injected failure rolls back aircraft, contract and offer'
);

select throws_ok(
    $$update private.aircraft_lease_events set event_type = 'expired'$$,
    '55000', 'Aircraft lease events are append-only.', 'lease history cannot be rewritten'
);
select results_eq(
    $$select count(*)::bigint from private.financial_ledger_entries entries
      where entries.entry_type = 'aircraft_lease_rent'
        and entries.idempotency_key in (
            select installments.id from public.aircraft_lease_installments installments
            where installments.contract_id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid
        )$$,
    $$select count(*)::bigint from public.aircraft_lease_installments
      where contract_id = (current_setting('t0032.creation')::jsonb ->> 'contractId')::uuid and state = 'paid'$$,
    'each paid obligation maps to exactly one immutable debit'
);

select * from finish();
rollback;
