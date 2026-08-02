begin;

select plan(20);

select has_table('public', 'aircraft_purchase_offers', 'purchase offers exist');
select has_table('public', 'company_aircraft', 'company aircraft exist');
select has_table('private', 'aircraft_purchase_commands', 'private purchase registry exists');

select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'public.aircraft_purchase_offers'::regclass),
    'purchase offers force RLS'
);
select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'public.company_aircraft'::regclass),
    'company aircraft force RLS'
);
select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'private.aircraft_purchase_commands'::regclass),
    'purchase registry forces RLS'
);

select table_privs_are(
    'public', 'aircraft_purchase_offers', 'authenticated', array['SELECT'],
    'authenticated can only read offers'
);
select table_privs_are(
    'public', 'company_aircraft', 'authenticated', array['SELECT'],
    'authenticated can only read aircraft'
);
select table_privs_are(
    'private', 'aircraft_purchase_commands', 'service_role', array[]::text[],
    'service role has no direct registry privileges'
);

select policies_are(
    'public', 'aircraft_purchase_offers', array['aircraft_purchase_offers_select_available'],
    'offers expose only the active-offer read policy'
);
select policies_are(
    'public', 'company_aircraft', array['company_aircraft_select_own'],
    'aircraft expose only the owner read policy'
);

select has_function(
    'public', 'purchase_aircraft', array['uuid', 'uuid', 'uuid'],
    'authoritative purchase command exists'
);
select has_function(
    'public', 'get_company_aircraft', array[]::text[],
    'owner aircraft read command exists'
);
select ok(
    has_function_privilege('service_role', 'public.purchase_aircraft(uuid,uuid,uuid)', 'EXECUTE'),
    'service role can execute purchase'
);
select ok(
    not has_function_privilege('authenticated', 'public.purchase_aircraft(uuid,uuid,uuid)', 'EXECUTE'),
    'authenticated cannot execute purchase'
);
select ok(
    not has_function_privilege('anon', 'public.purchase_aircraft(uuid,uuid,uuid)', 'EXECUTE'),
    'anonymous cannot execute purchase'
);
select ok(
    has_function_privilege('authenticated', 'public.get_company_aircraft()', 'EXECUTE'),
    'authenticated can read owned aircraft through the function'
);
select ok(
    not has_function_privilege('anon', 'public.get_company_aircraft()', 'EXECUTE'),
    'anonymous cannot invoke the aircraft reader'
);
select is(
    (select prosecdef from pg_proc
     where oid = 'public.purchase_aircraft(uuid,uuid,uuid)'::regprocedure),
    true,
    'purchase command is security definer'
);
select is(
    (select proconfig from pg_proc
     where oid = 'public.purchase_aircraft(uuid,uuid,uuid)'::regprocedure),
    array['search_path=""']::text[],
    'purchase command has an empty search path'
);

select * from finish();
rollback;
