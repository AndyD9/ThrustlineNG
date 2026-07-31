begin;

select plan(9);

select has_table(
    'public',
    'companies',
    'companies table exists'
);

select col_is_pk(
    'public',
    'companies',
    'id',
    'companies.id is the primary key'
);

select col_not_null(
    'public',
    'companies',
    'owner_id',
    'companies.owner_id is required'
);

select results_eq(
    $$select count(*)::bigint
      from pg_constraint
      where conrelid = 'public.companies'::regclass
        and contype = 'f'
        and pg_get_constraintdef(oid) like 'FOREIGN KEY (owner_id) REFERENCES auth.users(id)%'$$,
    array[1::bigint],
    'owner_id references auth.users'
);

select results_eq(
    $$select count(*)::bigint
      from pg_constraint
      where conrelid = 'public.companies'::regclass
        and contype = 'u'
        and conname = 'companies_one_per_owner'$$,
    array[1::bigint],
    'one company per owner is enforced'
);

select results_eq(
    $$select relrowsecurity
      from pg_class
      where oid = 'public.companies'::regclass$$,
    array[true],
    'RLS is enabled'
);

select results_eq(
    $$select relforcerowsecurity
      from pg_class
      where oid = 'public.companies'::regclass$$,
    array[true],
    'RLS is forced'
);

select policies_are(
    'public',
    'companies',
    array[
        'companies_select_own'
    ],
    'only the ownership read policy remains'
);

select results_eq(
    $$select count(*)::bigint
      from pg_policies
      where schemaname = 'public'
        and tablename = 'companies'
        and roles = array['authenticated']::name[]$$,
    array[1::bigint],
    'the read policy is restricted to authenticated'
);

select * from finish();
rollback;
