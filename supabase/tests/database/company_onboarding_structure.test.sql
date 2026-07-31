begin;

select plan(13);

select has_table(
    'private',
    'company_onboarding_commands',
    'private onboarding command registry exists'
);

select ok(
    (
        select relrowsecurity and relforcerowsecurity
        from pg_class
        where oid = 'private.company_onboarding_commands'::regclass
    ),
    'onboarding command registry forces RLS'
);

select table_privs_are(
    'private',
    'company_onboarding_commands',
    'authenticated',
    array[]::text[],
    'authenticated has no onboarding registry privileges'
);

select table_privs_are(
    'private',
    'company_onboarding_commands',
    'service_role',
    array[]::text[],
    'service role has no direct onboarding registry privileges'
);

select has_function(
    'public',
    'create_company_with_opening_balance',
    array['uuid', 'uuid', 'text', 'bigint', 'text'],
    'authoritative onboarding command exists'
);

select ok(
    has_function_privilege(
        'service_role',
        'public.create_company_with_opening_balance(uuid,uuid,text,bigint,text)',
        'EXECUTE'
    ),
    'service role can execute onboarding'
);

select ok(
    not has_function_privilege(
        'authenticated',
        'public.create_company_with_opening_balance(uuid,uuid,text,bigint,text)',
        'EXECUTE'
    ),
    'authenticated cannot execute onboarding'
);

select ok(
    not has_function_privilege(
        'anon',
        'public.create_company_with_opening_balance(uuid,uuid,text,bigint,text)',
        'EXECUTE'
    ),
    'anonymous cannot execute onboarding'
);

select is(
    (
        select prosecdef
        from pg_proc
        where oid = 'public.create_company_with_opening_balance(uuid,uuid,text,bigint,text)'::regprocedure
    ),
    true,
    'onboarding command is security definer'
);

select is(
    (
        select proconfig
        from pg_proc
        where oid = 'public.create_company_with_opening_balance(uuid,uuid,text,bigint,text)'::regprocedure
    ),
    array['search_path=""']::text[],
    'onboarding command has an empty search path'
);

select table_privs_are(
    'public',
    'companies',
    'authenticated',
    array['SELECT'],
    'authenticated can only read companies'
);

select policies_are(
    'public',
    'companies',
    array['companies_select_own'],
    'companies retain only the owner read policy'
);

select ok(
    (
        select count(*) = 3
        from pg_constraint
        where conrelid = 'private.company_onboarding_commands'::regclass
          and contype in ('c', 'p')
    ),
    'onboarding registry constrains identity, hash and response version'
);

select * from finish();
rollback;
