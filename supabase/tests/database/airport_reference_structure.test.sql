begin;

select plan(16);

select has_table('public', 'airports', 'the aerodrome reference exists');

select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'public.airports'::regclass),
    'the aerodrome reference forces RLS'
);

select col_is_pk('public', 'airports', 'icao_code', 'ICAO code is the reference identity');
select col_type_is('public', 'airports', 'latitude', 'numeric(7,4)', 'latitude is a bounded fixed-scale number');
select col_type_is('public', 'airports', 'longitude', 'numeric(8,4)', 'longitude is a bounded fixed-scale number');

select table_privs_are(
    'public', 'airports', 'authenticated', array['SELECT'],
    'authenticated can only read the reference'
);
select table_privs_are(
    'public', 'airports', 'anon', array[]::text[],
    'anonymous has no reference privileges'
);
select table_privs_are(
    'public', 'airports', 'service_role', array[]::text[],
    'service role has no direct reference privileges'
);
select policies_are(
    'public', 'airports', array['airports_select_reference'],
    'the reference exposes only its read policy'
);

select results_eq(
    $$select conname::text collate "default" from pg_constraint
      where conrelid = 'public.airports'::regclass and contype = 'c'
      order by 1$$,
    array[
        'airports_icao_code_format',
        'airports_latitude_bounds',
        'airports_longitude_bounds',
        'airports_name_bounded',
        'airports_popularity_tier',
        'airports_schema_version'
    ],
    'the reference constrains code, bounds, tier and schema version'
);

select has_function(
    'public', 'create_dispatch_draft', array['uuid', 'uuid', 'uuid', 'text', 'text'],
    'the dispatch command keeps its signature'
);
select ok(
    has_function_privilege(
        'service_role',
        'public.create_dispatch_draft(uuid,uuid,uuid,text,text)',
        'EXECUTE'
    ),
    'service role still executes dispatch creation'
);
select ok(
    not has_function_privilege(
        'authenticated',
        'public.create_dispatch_draft(uuid,uuid,uuid,text,text)',
        'EXECUTE'
    ),
    'authenticated still cannot execute dispatch creation'
);
select ok(
    not has_function_privilege(
        'anon',
        'public.create_dispatch_draft(uuid,uuid,uuid,text,text)',
        'EXECUTE'
    ),
    'anonymous still cannot execute dispatch creation'
);
select is(
    (select prosecdef from pg_proc
     where oid = 'public.create_dispatch_draft(uuid,uuid,uuid,text,text)'::regprocedure),
    true,
    'the dispatch command stays security definer'
);
select is(
    (select proconfig from pg_proc
     where oid = 'public.create_dispatch_draft(uuid,uuid,uuid,text,text)'::regprocedure),
    array['search_path=""']::text[],
    'the dispatch command keeps an empty search path'
);

select * from finish();
rollback;
