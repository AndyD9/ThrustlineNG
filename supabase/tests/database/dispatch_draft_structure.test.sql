begin;

select plan(14);

select has_table('public', 'flight_dispatches', 'flight dispatches exist');
select has_table('private', 'dispatch_draft_commands', 'private dispatch registry exists');

select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'public.flight_dispatches'::regclass),
    'flight dispatches force RLS'
);
select ok(
    (select relrowsecurity and relforcerowsecurity from pg_class
     where oid = 'private.dispatch_draft_commands'::regclass),
    'dispatch registry forces RLS'
);

select table_privs_are(
    'public', 'flight_dispatches', 'authenticated', array['SELECT'],
    'authenticated can only read dispatches'
);
select table_privs_are(
    'public', 'flight_dispatches', 'anon', array[]::text[],
    'anonymous has no dispatch privileges'
);
select table_privs_are(
    'private', 'dispatch_draft_commands', 'service_role', array[]::text[],
    'service role has no direct registry privileges'
);
select policies_are(
    'public', 'flight_dispatches', array['flight_dispatches_select_own'],
    'dispatches expose only the owner read policy'
);

select has_function(
    'public', 'create_dispatch_draft', array['uuid', 'uuid', 'uuid', 'text', 'text'],
    'authoritative dispatch command exists'
);
select ok(
    has_function_privilege(
        'service_role',
        'public.create_dispatch_draft(uuid,uuid,uuid,text,text)',
        'EXECUTE'
    ),
    'service role can create a dispatch draft'
);
select ok(
    not has_function_privilege(
        'authenticated',
        'public.create_dispatch_draft(uuid,uuid,uuid,text,text)',
        'EXECUTE'
    ),
    'authenticated cannot execute dispatch creation'
);
select ok(
    not has_function_privilege(
        'anon',
        'public.create_dispatch_draft(uuid,uuid,uuid,text,text)',
        'EXECUTE'
    ),
    'anonymous cannot execute dispatch creation'
);
select is(
    (select prosecdef from pg_proc
     where oid = 'public.create_dispatch_draft(uuid,uuid,uuid,text,text)'::regprocedure),
    true,
    'dispatch command is security definer'
);
select is(
    (select proconfig from pg_proc
     where oid = 'public.create_dispatch_draft(uuid,uuid,uuid,text,text)'::regprocedure),
    array['search_path=""']::text[],
    'dispatch command has an empty search path'
);

select * from finish();
rollback;
