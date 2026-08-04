begin;

select plan(18);

select has_table('private', 'flight_start_commands', 'private flight start registry exists');
select has_column('public', 'flight_dispatches', 'started_at', 'dispatches carry a departure timestamp');

select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'private.flight_start_commands'::regclass),
    'flight start registry forces RLS'
);
select table_privs_are(
    'private', 'flight_start_commands', 'service_role', array[]::text[],
    'service role has no direct flight start registry privileges'
);
select table_privs_are(
    'private', 'flight_start_commands', 'authenticated', array[]::text[],
    'authenticated has no flight start registry privileges'
);
select table_privs_are(
    'public', 'flight_dispatches', 'authenticated', array['SELECT'],
    'authenticated still only reads dispatches after the flight state opens'
);
select policies_are(
    'public', 'flight_dispatches', array['flight_dispatches_select_own'],
    'the flight state adds no dispatch policy'
);

select ok(
    exists (
        select 1 from pg_constraint
        where conrelid = 'public.flight_dispatches'::regclass
          and conname = 'flight_dispatches_known_states'
    ),
    'dispatch states are a closed list'
);
select ok(
    not exists (
        select 1 from pg_constraint
        where conrelid = 'public.flight_dispatches'::regclass
          and conname = 'flight_dispatches_draft_only'
    ),
    'the draft-only constraint is replaced instead of rewritten'
);
select ok(
    exists (
        select 1 from pg_constraint
        where conrelid = 'public.flight_dispatches'::regclass
          and conname = 'flight_dispatches_started_at_matches_state'
    ),
    'a departure timestamp exists only for an active flight'
);
-- T0050 asserted this exclusivity as a table constraint covering every known
-- state. T0051 opened two terminal states and replaced it with a partial unique
-- index, so the same invariant is now asserted where it actually lives: one open
-- dispatch per aircraft, history excluded.
select ok(
    (select indisunique from pg_index
     where indexrelid = 'public.flight_dispatches_one_open_per_aircraft'::regclass),
    'one dispatch per aircraft still covers every open state'
);
select has_trigger(
    'public', 'flight_dispatches', 'flight_dispatches_server_started_at',
    'a trigger derives the departure timestamp from PostgreSQL'
);

select has_function(
    'public', 'start_flight_from_dispatch', array['uuid', 'uuid', 'uuid'],
    'authoritative flight start command exists'
);
select ok(
    has_function_privilege(
        'service_role',
        'public.start_flight_from_dispatch(uuid,uuid,uuid)',
        'EXECUTE'
    ),
    'service role can start a flight'
);
select ok(
    not has_function_privilege(
        'authenticated',
        'public.start_flight_from_dispatch(uuid,uuid,uuid)',
        'EXECUTE'
    ),
    'authenticated cannot execute the flight start command'
);
select ok(
    not has_function_privilege(
        'anon',
        'public.start_flight_from_dispatch(uuid,uuid,uuid)',
        'EXECUTE'
    ),
    'anonymous cannot execute the flight start command'
);
select is(
    (select prosecdef from pg_proc
     where oid = 'public.start_flight_from_dispatch(uuid,uuid,uuid)'::regprocedure),
    true,
    'flight start command is security definer'
);
select is(
    (select proconfig from pg_proc
     where oid = 'public.start_flight_from_dispatch(uuid,uuid,uuid)'::regprocedure),
    array['search_path=""']::text[],
    'flight start command has an empty search path'
);

select * from finish();
rollback;
