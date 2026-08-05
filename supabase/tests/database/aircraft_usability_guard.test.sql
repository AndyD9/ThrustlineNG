begin;

select plan(37);

-- T0060 proves that public.company_aircraft.is_usable is opposable at the only
-- two entries that put an aircraft into service. Every unusable state below is
-- produced by the real T0032 lease commands, never by a direct write: grace
-- suspension, default at the grace boundary, a termination notice taking effect
-- and the natural expiry of a fully paid contract.
--
-- Approved terms of 4 August 2026 for a 10000 minor reference price: rent 25 per
-- 24 hours, a non-refundable set-up fee of ten rents, 72 hours of grace with the
-- aircraft suspended, and a termination penalty of two rents capped at the rent
-- still due. Activation therefore costs 250 + 25 = 275 minor, which sizes every
-- opening balance:
--   275  -> activation only, so the second rent can never be paid;
--   325  -> activation plus the 50 penalty of one voluntary termination;
--   1000 -> activation plus the 29 remaining rents, so the contract can expire.

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('60010000-0000-4000-8000-000000000001', 'usability-grace@thrustline.invalid', '{}', false),
    ('60020000-0000-4000-8000-000000000002', 'usability-default@thrustline.invalid', '{}', false),
    ('60030000-0000-4000-8000-000000000003', 'usability-terminated@thrustline.invalid', '{}', false),
    ('60040000-0000-4000-8000-000000000004', 'usability-expired@thrustline.invalid', '{}', false),
    ('60050000-0000-4000-8000-000000000005', 'usability-inflight@thrustline.invalid', '{}', false),
    ('60060000-0000-4000-8000-000000000006', 'usability-cash@thrustline.invalid', '{}', false),
    ('60070000-0000-4000-8000-000000000007', 'usability-recover@thrustline.invalid', '{}', false),
    ('60080000-0000-4000-8000-000000000008', 'usability-foreign@thrustline.invalid', '{}', false);

set local role service_role;
select public.create_company_with_opening_balance('60010000-0000-4000-8000-000000000001', '61010000-0000-4000-8000-000000000001', 'Usability Grace Air', 275, 'EUR');
select public.create_company_with_opening_balance('60020000-0000-4000-8000-000000000002', '61020000-0000-4000-8000-000000000002', 'Usability Default Air', 275, 'EUR');
select public.create_company_with_opening_balance('60030000-0000-4000-8000-000000000003', '61030000-0000-4000-8000-000000000003', 'Usability Terminated Air', 325, 'EUR');
select public.create_company_with_opening_balance('60040000-0000-4000-8000-000000000004', '61040000-0000-4000-8000-000000000004', 'Usability Expired Air', 1000, 'EUR');
select public.create_company_with_opening_balance('60050000-0000-4000-8000-000000000005', '61050000-0000-4000-8000-000000000005', 'Usability Inflight Air', 1000, 'EUR');
select public.create_company_with_opening_balance('60060000-0000-4000-8000-000000000006', '61060000-0000-4000-8000-000000000006', 'Usability Cash Air', 1000000, 'EUR');
select public.create_company_with_opening_balance('60070000-0000-4000-8000-000000000007', '61070000-0000-4000-8000-000000000007', 'Usability Recover Air', 275, 'EUR');
select public.create_company_with_opening_balance('60080000-0000-4000-8000-000000000008', '61080000-0000-4000-8000-000000000008', 'Usability Foreign Air', 1000000, 'EUR');
reset role;

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor, currency_code,
    offer_kind, terms_version, duration_days, cadence_hours, rent_minor,
    initial_payment_minor, grace_hours, voluntary_termination,
    termination_penalty_minor, usable_during_grace
)
values
    ('62010000-0000-4000-8000-000000000001', 'C172', 'T60-LEASE-GRACE', 'Usability Lease Grace', 10000, 'EUR', 'lease', 1, 30, 24, 25, 250, 72, true, 50, false),
    ('62020000-0000-4000-8000-000000000002', 'C172', 'T60-LEASE-DEFAULT', 'Usability Lease Default', 10000, 'EUR', 'lease', 1, 30, 24, 25, 250, 72, true, 50, false),
    ('62030000-0000-4000-8000-000000000003', 'C172', 'T60-LEASE-TERMINATED', 'Usability Lease Terminated', 10000, 'EUR', 'lease', 1, 30, 24, 25, 250, 72, true, 50, false),
    ('62040000-0000-4000-8000-000000000004', 'C172', 'T60-LEASE-EXPIRED', 'Usability Lease Expired', 10000, 'EUR', 'lease', 1, 30, 24, 25, 250, 72, true, 50, false),
    ('62050000-0000-4000-8000-000000000005', 'C172', 'T60-LEASE-INFLIGHT', 'Usability Lease Inflight', 10000, 'EUR', 'lease', 1, 30, 24, 25, 250, 72, true, 50, false),
    ('62070000-0000-4000-8000-000000000007', 'C172', 'T60-LEASE-RECOVER', 'Usability Lease Recover', 10000, 'EUR', 'lease', 1, 30, 24, 25, 250, 72, true, 50, false);

insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor, currency_code
)
values
    ('62060000-0000-4000-8000-000000000006', 'C172', 'T60-CASH-OWNED', 'Usability Cash Owned', 500000, 'EUR'),
    ('62080000-0000-4000-8000-000000000008', 'C172', 'T60-CASH-FOREIGN', 'Usability Cash Foreign', 500000, 'EUR');

-- Captures the SQLSTATE and message of a refusal so that two refusals can be
-- compared byte for byte. It proves the absence of a distinguishing channel:
-- an aircraft out of contract must be indistinguishable from a foreign one.
create function public.t0060_refusal(statement text)
returns text
language plpgsql
as $$
begin
    execute statement;
    return 'no refusal';
exception
    when others then
        return sqlstate || ' ' || sqlerrm;
end;
$$;

-- The block redefinition must not weaken the hardening of either command, and
-- must not add a caller-controlled usage parameter to either signature.
select is(
    (
        select string_agg(
            routines.proname::text || '|' || routines.prosecdef::text || '|' ||
                coalesce(array_to_string(routines.proconfig, ','), ''),
            ' '
            order by routines.proname::text
        )
        from pg_catalog.pg_proc as routines
        join pg_catalog.pg_namespace as schemas on schemas.oid = routines.pronamespace
        where schemas.nspname = 'public'
          and routines.proname::text in ('create_dispatch_draft', 'start_flight_from_dispatch')
    ),
    'create_dispatch_draft|true|search_path="" start_flight_from_dispatch|true|search_path=""',
    'both service commands stay security definer with an empty search path'
);
select is(
    pg_catalog.pg_get_function_arguments(
        'public.create_dispatch_draft(uuid, uuid, uuid, text, text)'::regprocedure
    ),
    'owner_id uuid, idempotency_key uuid, aircraft_id uuid, departure_icao text, arrival_icao text',
    'the dispatch command keeps its exact signature without a usage parameter'
);
select is(
    pg_catalog.pg_get_function_arguments(
        'public.start_flight_from_dispatch(uuid, uuid, uuid)'::regprocedure
    ),
    'owner_id uuid, idempotency_key uuid, dispatch_id uuid',
    'the flight start keeps its exact signature without a usage parameter'
);

set local role authenticated;
select throws_ok(
    $$select public.create_dispatch_draft('60060000-0000-4000-8000-000000000006',
        '63960000-0000-4000-8000-000000000006', '60060000-0000-4000-8000-000000000006', 'LFPG', 'LFPO')$$,
    '42501', 'permission denied for function create_dispatch_draft',
    'authenticated cannot execute the guarded dispatch command'
);
select throws_ok(
    $$select public.start_flight_from_dispatch('60060000-0000-4000-8000-000000000006',
        '63960000-0000-4000-8000-000000000006', '60060000-0000-4000-8000-000000000006')$$,
    '42501', 'permission denied for function start_flight_from_dispatch',
    'authenticated cannot execute the guarded flight start command'
);
select throws_ok(
    $$update public.company_aircraft set is_usable = true$$,
    '42501', 'permission denied for table company_aircraft',
    'authenticated cannot write the aircraft usage state directly'
);
reset role;

set local role anon;
select throws_ok(
    $$select public.create_dispatch_draft('60060000-0000-4000-8000-000000000006',
        '63960000-0000-4000-8000-000000000006', '60060000-0000-4000-8000-000000000006', 'LFPG', 'LFPO')$$,
    '42501', 'permission denied for function create_dispatch_draft',
    'anonymous cannot execute the guarded dispatch command'
);
select throws_ok(
    $$select public.start_flight_from_dispatch('60060000-0000-4000-8000-000000000006',
        '63960000-0000-4000-8000-000000000006', '60060000-0000-4000-8000-000000000006')$$,
    '42501', 'permission denied for function start_flight_from_dispatch',
    'anonymous cannot execute the guarded flight start command'
);
select throws_ok(
    $$update public.company_aircraft set is_usable = true$$,
    '42501', 'permission denied for table company_aircraft',
    'anonymous cannot write the aircraft usage state directly'
);
reset role;

-- No regression: an aircraft bought outright by T0029 and an aircraft under an
-- active lease are both dispatchable and startable.
set local role service_role;
select set_config('t0060.cash_aircraft', public.purchase_aircraft(
    '60060000-0000-4000-8000-000000000006', '63160000-0000-4000-8000-000000000006',
    '62060000-0000-4000-8000-000000000006'
) ->> 'aircraftId', true);
select set_config('t0060.cash_draft', public.create_dispatch_draft(
    '60060000-0000-4000-8000-000000000006', '63260000-0000-4000-8000-000000000006',
    current_setting('t0060.cash_aircraft')::uuid, 'LFPG', 'LFPO'
)::text, true);
select set_config('t0060.cash_start', public.start_flight_from_dispatch(
    '60060000-0000-4000-8000-000000000006', '63360000-0000-4000-8000-000000000006',
    (current_setting('t0060.cash_draft')::jsonb ->> 'dispatchId')::uuid
)::text, true);

select set_config('t0060.foreign_aircraft', public.purchase_aircraft(
    '60080000-0000-4000-8000-000000000008', '63180000-0000-4000-8000-000000000008',
    '62080000-0000-4000-8000-000000000008'
) ->> 'aircraftId', true);
select set_config('t0060.foreign_dispatch', public.create_dispatch_draft(
    '60080000-0000-4000-8000-000000000008', '63280000-0000-4000-8000-000000000008',
    current_setting('t0060.foreign_aircraft')::uuid, 'LFBO', 'LFML'
) ->> 'dispatchId', true);

select set_config('t0060.inflight_lease', public.lease_aircraft(
    '60050000-0000-4000-8000-000000000005', '63050000-0000-4000-8000-000000000005',
    '62050000-0000-4000-8000-000000000005'
)::text, true);
select set_config('t0060.inflight_draft', public.create_dispatch_draft(
    '60050000-0000-4000-8000-000000000005', '63150000-0000-4000-8000-000000000005',
    (current_setting('t0060.inflight_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'LFPO'
)::text, true);
select set_config('t0060.inflight_start', public.start_flight_from_dispatch(
    '60050000-0000-4000-8000-000000000005', '63250000-0000-4000-8000-000000000005',
    (current_setting('t0060.inflight_draft')::jsonb ->> 'dispatchId')::uuid
)::text, true);
reset role;

select is(
    current_setting('t0060.cash_draft')::jsonb ->> 'state', 'draft',
    'a cash-bought usable aircraft still receives a dispatch draft'
);
select is(
    current_setting('t0060.cash_start')::jsonb ->> 'state', 'active',
    'a cash-bought usable aircraft still starts its flight'
);
select is(
    current_setting('t0060.inflight_draft')::jsonb ->> 'state', 'draft',
    'an aircraft under an active lease still receives a dispatch draft'
);
select is(
    current_setting('t0060.inflight_start')::jsonb ->> 'state', 'active',
    'an aircraft under an active lease still starts its flight'
);

-- The reference refusals: the aircraft and the dispatch of another company.
set local role service_role;
select throws_ok(
    $$select public.create_dispatch_draft('60060000-0000-4000-8000-000000000006',
        '63460000-0000-4000-8000-000000000006',
        current_setting('t0060.foreign_aircraft')::uuid, 'LFPG', 'EGLL')$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'an aircraft owned by another company is refused for dispatch'
);
select throws_ok(
    $$select public.start_flight_from_dispatch('60060000-0000-4000-8000-000000000006',
        '63560000-0000-4000-8000-000000000006',
        current_setting('t0060.foreign_dispatch')::uuid)$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'a dispatch owned by another company is refused for flight start'
);
reset role;

-- Unusable state 1 of 4: the aircraft is suspended for the whole grace window.
set local role service_role;
select set_config('t0060.grace_lease', public.lease_aircraft(
    '60010000-0000-4000-8000-000000000001', '63010000-0000-4000-8000-000000000001',
    '62010000-0000-4000-8000-000000000001'
)::text, true);
select set_config('t0060.grace_dispatch', public.create_dispatch_draft(
    '60010000-0000-4000-8000-000000000001', '63110000-0000-4000-8000-000000000001',
    (current_setting('t0060.grace_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'LFPO'
) ->> 'dispatchId', true);
reset role;
select set_config('t0060.grace_at', (
    select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0060.grace_lease')::jsonb ->> 'contractId')::uuid
), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0060.grace_lease')::jsonb ->> 'contractId')::uuid,
    '63210000-0000-4000-8000-000000000001',
    current_setting('t0060.grace_at')::timestamptz + interval '24 hours'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable
      from public.aircraft_lease_contracts as contracts
      join public.company_aircraft as aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0060.grace_lease')::jsonb ->> 'contractId')::uuid$$,
    $$values ('grace'::text, false)$$,
    'an unpaid rent suspends the aircraft for the grace window'
);
set local role service_role;
select throws_ok(
    $$select public.start_flight_from_dispatch('60010000-0000-4000-8000-000000000001',
        '63310000-0000-4000-8000-000000000001',
        current_setting('t0060.grace_dispatch')::uuid)$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'a draft created while usable cannot depart once usage is suspended'
);
select throws_ok(
    $$select public.create_dispatch_draft('60010000-0000-4000-8000-000000000001',
        '63410000-0000-4000-8000-000000000001',
        (current_setting('t0060.grace_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'EGLL')$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'a suspended aircraft receives no new dispatch draft'
);
reset role;
select is(
    public.t0060_refusal(format(
        'select public.create_dispatch_draft(%L, %L, %L, %L, %L)',
        '60010000-0000-4000-8000-000000000001', '63510000-0000-4000-8000-000000000001',
        current_setting('t0060.grace_lease')::jsonb ->> 'aircraftId', 'LFPG', 'LFBO'
    )),
    public.t0060_refusal(format(
        'select public.create_dispatch_draft(%L, %L, %L, %L, %L)',
        '60060000-0000-4000-8000-000000000006', '63610000-0000-4000-8000-000000000006',
        current_setting('t0060.foreign_aircraft'), 'LFPG', 'LFBO'
    )),
    'an unusable aircraft is indistinguishable from a foreign aircraft at dispatch'
);
select is(
    public.t0060_refusal(format(
        'select public.start_flight_from_dispatch(%L, %L, %L)',
        '60010000-0000-4000-8000-000000000001', '63710000-0000-4000-8000-000000000001',
        current_setting('t0060.grace_dispatch')
    )),
    public.t0060_refusal(format(
        'select public.start_flight_from_dispatch(%L, %L, %L)',
        '60060000-0000-4000-8000-000000000006', '63710000-0000-4000-8000-000000000006',
        current_setting('t0060.foreign_dispatch')
    )),
    'an unusable aircraft is indistinguishable from a foreign dispatch at flight start'
);

-- Unusable state 2 of 4: the grace window expires and the contract defaults.
set local role service_role;
select set_config('t0060.default_lease', public.lease_aircraft(
    '60020000-0000-4000-8000-000000000002', '63020000-0000-4000-8000-000000000002',
    '62020000-0000-4000-8000-000000000002'
)::text, true);
select set_config('t0060.default_dispatch', public.create_dispatch_draft(
    '60020000-0000-4000-8000-000000000002', '63120000-0000-4000-8000-000000000002',
    (current_setting('t0060.default_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'LFPO'
) ->> 'dispatchId', true);
reset role;
select set_config('t0060.default_at', (
    select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0060.default_lease')::jsonb ->> 'contractId')::uuid
), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0060.default_lease')::jsonb ->> 'contractId')::uuid,
    '63220000-0000-4000-8000-000000000002',
    current_setting('t0060.default_at')::timestamptz + interval '96 hours'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable
      from public.aircraft_lease_contracts as contracts
      join public.company_aircraft as aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0060.default_lease')::jsonb ->> 'contractId')::uuid$$,
    $$values ('defaulted'::text, false)$$,
    'the 72-hour grace boundary defaults the contract and removes usage'
);
set local role service_role;
select throws_ok(
    $$select public.start_flight_from_dispatch('60020000-0000-4000-8000-000000000002',
        '63320000-0000-4000-8000-000000000002',
        current_setting('t0060.default_dispatch')::uuid)$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'a defaulted lease stops the departure of an existing draft'
);
select throws_ok(
    $$select public.create_dispatch_draft('60020000-0000-4000-8000-000000000002',
        '63420000-0000-4000-8000-000000000002',
        (current_setting('t0060.default_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'EGLL')$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'a defaulted lease receives no new dispatch draft'
);
reset role;

-- Unusable state 3 of 4: a voluntary termination notice takes effect.
set local role service_role;
select set_config('t0060.terminated_lease', public.lease_aircraft(
    '60030000-0000-4000-8000-000000000003', '63030000-0000-4000-8000-000000000003',
    '62030000-0000-4000-8000-000000000003'
)::text, true);
select set_config('t0060.terminated_dispatch', public.create_dispatch_draft(
    '60030000-0000-4000-8000-000000000003', '63130000-0000-4000-8000-000000000003',
    (current_setting('t0060.terminated_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'LFPO'
) ->> 'dispatchId', true);
select public.terminate_aircraft_lease(
    '60030000-0000-4000-8000-000000000003',
    (current_setting('t0060.terminated_lease')::jsonb ->> 'contractId')::uuid,
    '63230000-0000-4000-8000-000000000003'
);
reset role;
select set_config('t0060.terminated_at', (
    select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0060.terminated_lease')::jsonb ->> 'contractId')::uuid
), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0060.terminated_lease')::jsonb ->> 'contractId')::uuid,
    '63330000-0000-4000-8000-000000000003',
    current_setting('t0060.terminated_at')::timestamptz + interval '24 hours'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable
      from public.aircraft_lease_contracts as contracts
      join public.company_aircraft as aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0060.terminated_lease')::jsonb ->> 'contractId')::uuid$$,
    $$values ('terminated'::text, false)$$,
    'a termination notice taking effect removes usage'
);
set local role service_role;
select throws_ok(
    $$select public.start_flight_from_dispatch('60030000-0000-4000-8000-000000000003',
        '63430000-0000-4000-8000-000000000003',
        current_setting('t0060.terminated_dispatch')::uuid)$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'a terminated lease stops the departure of an existing draft'
);
select throws_ok(
    $$select public.create_dispatch_draft('60030000-0000-4000-8000-000000000003',
        '63530000-0000-4000-8000-000000000003',
        (current_setting('t0060.terminated_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'EGLL')$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'a terminated lease receives no new dispatch draft'
);
reset role;

-- Unusable state 4 of 4: a fully paid contract reaches its natural end.
set local role service_role;
select set_config('t0060.expired_lease', public.lease_aircraft(
    '60040000-0000-4000-8000-000000000004', '63040000-0000-4000-8000-000000000004',
    '62040000-0000-4000-8000-000000000004'
)::text, true);
select set_config('t0060.expired_dispatch', public.create_dispatch_draft(
    '60040000-0000-4000-8000-000000000004', '63140000-0000-4000-8000-000000000004',
    (current_setting('t0060.expired_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'LFPO'
) ->> 'dispatchId', true);
reset role;
select set_config('t0060.expired_at', (
    select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0060.expired_lease')::jsonb ->> 'contractId')::uuid
), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0060.expired_lease')::jsonb ->> 'contractId')::uuid,
    '63240000-0000-4000-8000-000000000004',
    current_setting('t0060.expired_at')::timestamptz + interval '30 days'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable
      from public.aircraft_lease_contracts as contracts
      join public.company_aircraft as aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0060.expired_lease')::jsonb ->> 'contractId')::uuid$$,
    $$values ('expired'::text, false)$$,
    'a fully paid contract expires and removes usage'
);
set local role service_role;
select throws_ok(
    $$select public.start_flight_from_dispatch('60040000-0000-4000-8000-000000000004',
        '63340000-0000-4000-8000-000000000004',
        current_setting('t0060.expired_dispatch')::uuid)$$,
    '55000', 'Dispatch is unavailable for flight start.',
    'an expired lease stops the departure of an existing draft'
);
select throws_ok(
    $$select public.create_dispatch_draft('60040000-0000-4000-8000-000000000004',
        '63440000-0000-4000-8000-000000000004',
        (current_setting('t0060.expired_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'EGLL')$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'an expired lease receives no new dispatch draft'
);
reset role;

-- Coming back from grace to active through the privileged temporal command
-- makes the same aircraft dispatchable again.
set local role service_role;
select set_config('t0060.recover_lease', public.lease_aircraft(
    '60070000-0000-4000-8000-000000000007', '63070000-0000-4000-8000-000000000007',
    '62070000-0000-4000-8000-000000000007'
)::text, true);
reset role;
select set_config('t0060.recover_at', (
    select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0060.recover_lease')::jsonb ->> 'contractId')::uuid
), true);
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0060.recover_lease')::jsonb ->> 'contractId')::uuid,
    '63170000-0000-4000-8000-000000000007',
    current_setting('t0060.recover_at')::timestamptz + interval '24 hours'
);
select throws_ok(
    $$select public.create_dispatch_draft('60070000-0000-4000-8000-000000000007',
        '63270000-0000-4000-8000-000000000007',
        (current_setting('t0060.recover_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'LFPO')$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'the suspended aircraft of the recovery fixture is refused first'
);
reset role;
insert into private.financial_ledger_entries (
    subject_id, sequence_number, idempotency_key, entry_type, amount_minor, currency_code
)
select subjects.subject_id,
       (select coalesce(max(sequence_number), 0) + 1 from private.financial_ledger_entries as existing
        where existing.subject_id = subjects.subject_id),
       gen_random_uuid(), 'flight_settlement', 100, 'EUR'
from private.financial_ledger_subjects as subjects
join public.companies on companies.id = subjects.company_id
where companies.owner_id = '60070000-0000-4000-8000-000000000007';
set local role service_role;
select public.process_aircraft_lease(
    (current_setting('t0060.recover_lease')::jsonb ->> 'contractId')::uuid,
    '63370000-0000-4000-8000-000000000007',
    current_setting('t0060.recover_at')::timestamptz + interval '30 hours'
);
select set_config('t0060.recover_draft', public.create_dispatch_draft(
    '60070000-0000-4000-8000-000000000007', '63470000-0000-4000-8000-000000000007',
    (current_setting('t0060.recover_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'LFPO'
)::text, true);
select set_config('t0060.recover_start', public.start_flight_from_dispatch(
    '60070000-0000-4000-8000-000000000007', '63570000-0000-4000-8000-000000000007',
    (current_setting('t0060.recover_draft')::jsonb ->> 'dispatchId')::uuid
)::text, true);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable
      from public.aircraft_lease_contracts as contracts
      join public.company_aircraft as aircraft on aircraft.id = contracts.aircraft_id
      where contracts.id = (current_setting('t0060.recover_lease')::jsonb ->> 'contractId')::uuid$$,
    $$values ('active'::text, true)$$,
    'clearing every arrear restores the contract and the usage'
);
select is(
    current_setting('t0060.recover_draft')::jsonb ->> 'state', 'draft',
    'an aircraft back from grace to active is dispatchable again'
);
select is(
    current_setting('t0060.recover_start')::jsonb ->> 'state', 'active',
    'an aircraft back from grace to active departs again'
);

-- Andy's decision of 4 August 2026: a flight already under way stays closeable
-- even after the aircraft becomes unusable, and its replay is untouched. The
-- same aircraft is refused for any new draft afterwards.
select set_config('t0060.inflight_at', (
    select activated_at::text from public.aircraft_lease_contracts
    where id = (current_setting('t0060.inflight_lease')::jsonb ->> 'contractId')::uuid
), true);
set local role service_role;
select public.terminate_aircraft_lease(
    '60050000-0000-4000-8000-000000000005',
    (current_setting('t0060.inflight_lease')::jsonb ->> 'contractId')::uuid,
    '63350000-0000-4000-8000-000000000005'
);
select public.process_aircraft_lease(
    (current_setting('t0060.inflight_lease')::jsonb ->> 'contractId')::uuid,
    '63450000-0000-4000-8000-000000000005',
    current_setting('t0060.inflight_at')::timestamptz + interval '24 hours'
);
reset role;
select results_eq(
    $$select contracts.state, aircraft.is_usable, dispatches.state
      from public.aircraft_lease_contracts as contracts
      join public.company_aircraft as aircraft on aircraft.id = contracts.aircraft_id
      join public.flight_dispatches as dispatches on dispatches.aircraft_id = aircraft.id
      where contracts.id = (current_setting('t0060.inflight_lease')::jsonb ->> 'contractId')::uuid$$,
    $$values ('terminated'::text, false, 'active'::text)$$,
    'the aircraft of a flight under way becomes unusable while the flight stays active'
);
set local role service_role;
select is(
    public.start_flight_from_dispatch(
        '60050000-0000-4000-8000-000000000005', '63250000-0000-4000-8000-000000000005',
        (current_setting('t0060.inflight_draft')::jsonb ->> 'dispatchId')::uuid
    )::text,
    current_setting('t0060.inflight_start'),
    'a start acquired before the usage loss replays the stored response identically'
);
select set_config('t0060.closure', public.close_flight(
    '60050000-0000-4000-8000-000000000005', '63550000-0000-4000-8000-000000000005',
    (current_setting('t0060.inflight_draft')::jsonb ->> 'dispatchId')::uuid,
    '{"outcome": "completed", "blockMinutes": 0}'::jsonb
)::text, true);
reset role;
select results_eq(
    $$select dispatches.state,
             current_setting('t0060.closure')::jsonb ->> 'outcome',
             (current_setting('t0060.closure')::jsonb ->> 'settledAmountMinor')::bigint > 0
      from public.flight_dispatches as dispatches
      where dispatches.id = (current_setting('t0060.inflight_draft')::jsonb ->> 'dispatchId')::uuid$$,
    $$values ('completed'::text, 'completed'::text, true)$$,
    'a flight already under way is still closed and settled on an unusable aircraft'
);
set local role service_role;
select throws_ok(
    $$select public.create_dispatch_draft('60050000-0000-4000-8000-000000000005',
        '63650000-0000-4000-8000-000000000005',
        (current_setting('t0060.inflight_lease')::jsonb ->> 'aircraftId')::uuid, 'LFPG', 'EGLL')$$,
    '55000', 'Aircraft is unavailable for dispatch.',
    'the closed flight does not make the unusable aircraft dispatchable again'
);
reset role;

select * from finish();
rollback;
