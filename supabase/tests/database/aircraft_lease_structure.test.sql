begin;

select plan(32);

select has_table('public', 'aircraft_lease_contracts', 'lease contracts exist');
select has_table('public', 'aircraft_lease_installments', 'lease installments exist');
select has_table('private', 'aircraft_lease_events', 'private lease event history exists');
select has_table('private', 'aircraft_lease_creation_commands', 'private lease creation registry exists');
select has_table('private', 'aircraft_lease_temporal_commands', 'private temporal registry exists');
select has_table('private', 'aircraft_lease_termination_commands', 'private termination registry exists');

select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.aircraft_lease_contracts'::regclass),
    'lease contracts force RLS'
);
select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.aircraft_lease_installments'::regclass),
    'lease installments force RLS'
);
select ok(
    (select bool_and(relrowsecurity and relforcerowsecurity) from pg_class
     where oid in (
        'private.aircraft_lease_events'::regclass,
        'private.aircraft_lease_creation_commands'::regclass,
        'private.aircraft_lease_temporal_commands'::regclass,
        'private.aircraft_lease_termination_commands'::regclass
     )),
    'private lease registries force RLS'
);

select table_privs_are('public', 'aircraft_lease_contracts', 'authenticated', array['SELECT'],
    'authenticated can only read contracts');
select table_privs_are('public', 'aircraft_lease_installments', 'authenticated', array['SELECT'],
    'authenticated can only read installments');
select table_privs_are('private', 'aircraft_lease_events', 'service_role', array[]::text[],
    'service role has no direct event privileges');

select policies_are('public', 'aircraft_lease_contracts', array['aircraft_lease_contracts_select_own'],
    'contracts expose only the owner policy');
select policies_are('public', 'aircraft_lease_installments', array['aircraft_lease_installments_select_own'],
    'installments expose only the owner policy');

select has_function('public', 'lease_aircraft', array['uuid', 'uuid', 'uuid'],
    'authoritative lease creation exists');
select has_function('public', 'process_aircraft_lease', array['uuid', 'uuid', 'timestamp with time zone'],
    'authoritative temporal catch-up exists');
select has_function('public', 'terminate_aircraft_lease', array['uuid', 'uuid', 'uuid'],
    'authoritative termination exists');

select ok(has_function_privilege('service_role', 'public.lease_aircraft(uuid,uuid,uuid)', 'EXECUTE'),
    'service role can create a lease');
select ok(not has_function_privilege('authenticated', 'public.lease_aircraft(uuid,uuid,uuid)', 'EXECUTE'),
    'authenticated cannot create a lease directly');
select ok(not has_function_privilege('anon', 'public.lease_aircraft(uuid,uuid,uuid)', 'EXECUTE'),
    'anonymous cannot create a lease');
select ok(has_function_privilege('service_role', 'public.process_aircraft_lease(uuid,uuid,timestamp with time zone)', 'EXECUTE'),
    'service role owns temporal authority');
select ok(not has_function_privilege('authenticated', 'public.process_aircraft_lease(uuid,uuid,timestamp with time zone)', 'EXECUTE'),
    'authenticated has no temporal authority');
select ok(has_function_privilege('service_role', 'public.terminate_aircraft_lease(uuid,uuid,uuid)', 'EXECUTE'),
    'service role can terminate a lease');
select ok(not has_function_privilege('authenticated', 'public.terminate_aircraft_lease(uuid,uuid,uuid)', 'EXECUTE'),
    'authenticated cannot terminate directly');

select is((select prosecdef from pg_proc where oid = 'public.lease_aircraft(uuid,uuid,uuid)'::regprocedure), true,
    'lease creation is security definer');
select is((select proconfig from pg_proc where oid = 'public.process_aircraft_lease(uuid,uuid,timestamp with time zone)'::regprocedure),
    array['search_path=""']::text[], 'temporal command has empty search path');
select has_column('public', 'aircraft_lease_contracts', 'terminate_effective_at',
    'a notified termination carries its server effective instant');
select ok(
    (select pg_get_constraintdef(oid) like '%terminating%' from pg_constraint
     where conname = 'aircraft_lease_contract_state'),
    'the notice state is part of the authorized transitions'
);
select has_column('private', 'aircraft_lease_creation_commands', 'setup_ledger_entry_id',
    'the creation registry pins the set-up fee debit');
select has_column('private', 'aircraft_lease_termination_commands', 'penalty_minor',
    'the termination registry pins the penalty actually charged');

select has_trigger('private', 'aircraft_lease_events', 'aircraft_lease_events_reject_update_delete',
    'lease event history rejects update and delete');
select has_trigger('public', 'companies', 'companies_terminate_aircraft_leases',
    'company deletion terminates and detaches active leases');

select * from finish();
rollback;
