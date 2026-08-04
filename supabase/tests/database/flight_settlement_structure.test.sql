begin;

select plan(32);

select has_table('private', 'flight_reports', 'private flight report table exists');
select has_table('private', 'company_reputation_events', 'private reputation event table exists');
select has_table('private', 'flight_close_commands', 'private flight closure registry exists');
select has_column('public', 'flight_dispatches', 'closed_at', 'dispatches carry a closing timestamp');

select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'private.flight_reports'::regclass),
    'flight reports force RLS'
);
select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'private.company_reputation_events'::regclass),
    'reputation events force RLS'
);
select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'private.flight_close_commands'::regclass),
    'flight closure registry forces RLS'
);

select table_privs_are(
    'private', 'flight_reports', 'service_role', array[]::text[],
    'service role has no direct flight report privileges'
);
select table_privs_are(
    'private', 'flight_reports', 'authenticated', array[]::text[],
    'authenticated has no flight report privileges'
);
select table_privs_are(
    'private', 'company_reputation_events', 'service_role', array[]::text[],
    'service role has no direct reputation privileges'
);
select table_privs_are(
    'private', 'company_reputation_events', 'authenticated', array[]::text[],
    'authenticated has no reputation privileges'
);
select table_privs_are(
    'private', 'company_reputation_events', 'anon', array[]::text[],
    'anonymous has no reputation privileges'
);
select table_privs_are(
    'private', 'flight_close_commands', 'authenticated', array[]::text[],
    'authenticated has no flight closure registry privileges'
);
select table_privs_are(
    'public', 'flight_dispatches', 'authenticated', array['SELECT'],
    'authenticated still only reads dispatches after the terminal states open'
);
select policies_are(
    'public', 'flight_dispatches', array['flight_dispatches_select_own'],
    'the settlement adds no dispatch policy'
);

select ok(
    (select pg_get_constraintdef(oid) like '%''completed''%''interrupted''%'
     from pg_constraint
     where conrelid = 'public.flight_dispatches'::regclass
       and conname = 'flight_dispatches_known_states'),
    'dispatch states are a closed list of four'
);
select ok(
    exists (
        select 1 from pg_constraint
        where conrelid = 'public.flight_dispatches'::regclass
          and conname = 'flight_dispatches_closed_at_matches_state'
    ),
    'a closing timestamp exists only for a terminal flight'
);
select ok(
    exists (
        select 1 from pg_constraint
        where conrelid = 'public.flight_dispatches'::regclass
          and conname = 'flight_dispatches_closed_after_start'
    ),
    'a flight never closes before it departs'
);
select ok(
    not exists (
        select 1 from pg_constraint
        where conrelid = 'public.flight_dispatches'::regclass
          and conname = 'flight_dispatches_one_draft_per_aircraft'
    ),
    'the global one-dispatch-per-aircraft constraint is replaced'
);
select ok(
    (select indisunique and indpred is not null from pg_index
     where indexrelid = 'public.flight_dispatches_one_open_per_aircraft'::regclass),
    'exclusivity per aircraft is a partial unique index covering non-terminal states only'
);
select ok(
    not exists (
        select 1 from pg_constraint
        where conrelid = 'private.dispatch_draft_commands'::regclass
          and conname = 'dispatch_draft_commands_aircraft'
    ),
    'the draft registry no longer duplicates aircraft exclusivity'
);
select ok(
    (select pg_get_constraintdef(oid) like '%flight_settlement%'
     from pg_constraint
     where conrelid = 'private.financial_ledger_entries'::regclass
       and conname = 'financial_ledger_entries_known_type'),
    'the ledger knows the settlement entry type'
);
select ok(
    exists (
        select 1 from pg_constraint
        where conrelid = 'private.financial_ledger_entries'::regclass
          and conname = 'financial_ledger_entries_settlement_positive'
    ),
    'a settlement entry can only be a credit'
);

select has_trigger(
    'private', 'company_reputation_events',
    'company_reputation_events_reject_update_delete',
    'reputation events reject updates and deletes'
);
select has_trigger(
    'private', 'company_reputation_events',
    'company_reputation_events_reject_truncate',
    'reputation events reject truncation'
);

select has_function(
    'public', 'close_flight', array['uuid', 'uuid', 'uuid', 'jsonb'],
    'authoritative flight closure command exists'
);
select ok(
    has_function_privilege(
        'service_role',
        'public.close_flight(uuid,uuid,uuid,jsonb)',
        'EXECUTE'
    )
    and not has_function_privilege(
        'authenticated',
        'public.close_flight(uuid,uuid,uuid,jsonb)',
        'EXECUTE'
    )
    and not has_function_privilege(
        'anon',
        'public.close_flight(uuid,uuid,uuid,jsonb)',
        'EXECUTE'
    ),
    'only the service role can close a flight'
);
select is(
    (select prosecdef from pg_proc
     where oid = 'public.close_flight(uuid,uuid,uuid,jsonb)'::regprocedure),
    true,
    'flight closure command is security definer'
);
select is(
    (select proconfig from pg_proc
     where oid = 'public.close_flight(uuid,uuid,uuid,jsonb)'::regprocedure),
    array['search_path=""']::text[],
    'flight closure command has an empty search path'
);

select has_function(
    'public', 'get_company_reputation', array[]::text[],
    'owner-scoped reputation read exists'
);
select ok(
    has_function_privilege(
        'authenticated',
        'public.get_company_reputation()',
        'EXECUTE'
    )
    and not has_function_privilege(
        'anon',
        'public.get_company_reputation()',
        'EXECUTE'
    ),
    'only an authenticated role reads a reputation score'
);
select ok(
    not has_function_privilege(
        'authenticated',
        'private.flight_settlement_policy()',
        'EXECUTE'
    )
    and not has_function_privilege(
        'service_role',
        'private.flight_settlement_policy()',
        'EXECUTE'
    ),
    'no API role reads the settlement policy directly'
);

select * from finish();
rollback;
