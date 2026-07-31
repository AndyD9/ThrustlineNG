begin;

select plan(16);

select has_schema(
    'private',
    'private schema exists'
);

select has_table(
    'private',
    'account_deletion_requests',
    'account deletion requests table exists'
);

select has_table(
    'private',
    'account_lifecycle_commands',
    'account lifecycle command ledger exists'
);

select has_table(
    'private',
    'account_deletion_markers',
    'non-personal deletion marker table exists'
);

select results_eq(
    $$select count(*)::bigint
      from pg_class
      where oid in (
          'private.account_deletion_requests'::regclass,
          'private.account_lifecycle_commands'::regclass,
          'private.account_deletion_markers'::regclass
      )
        and relrowsecurity
        and relforcerowsecurity$$,
    array[3::bigint],
    'every private lifecycle table enables and forces RLS'
);

select results_eq(
    $$select count(*)::bigint
      from information_schema.role_table_grants
      where table_schema = 'private'
        and grantee in ('anon', 'authenticated')$$,
    array[0::bigint],
    'API roles have no direct private table privileges'
);

select has_function(
    'public',
    'request_account_deletion',
    array['uuid'],
    'request command exists'
);

select has_function(
    'public',
    'get_account_export',
    array['uuid'],
    'export recovery command exists'
);

select has_function(
    'public',
    'cancel_account_deletion',
    array['uuid', 'uuid'],
    'cancellation command exists'
);

select has_function(
    'public',
    'finalize_account_deletion',
    array['uuid'],
    'server finalization command exists'
);

select ok(
    has_function_privilege(
        'authenticated',
        'public.request_account_deletion(uuid)',
        'EXECUTE'
    ),
    'authenticated can request its own deletion'
);

select ok(
    has_function_privilege(
        'authenticated',
        'public.get_account_export(uuid)',
        'EXECUTE'
    ),
    'authenticated can recover its own export'
);

select ok(
    has_function_privilege(
        'authenticated',
        'public.cancel_account_deletion(uuid,uuid)',
        'EXECUTE'
    ),
    'authenticated can cancel its own deletion'
);

select ok(
    not has_function_privilege(
        'authenticated',
        'public.finalize_account_deletion(uuid)',
        'EXECUTE'
    ),
    'authenticated cannot finalize an account deletion'
);

select results_eq(
    $$select count(*)::bigint
      from pg_proc
      where oid in (
          'public.request_account_deletion(uuid)'::regprocedure,
          'public.get_account_export(uuid)'::regprocedure,
          'public.cancel_account_deletion(uuid,uuid)'::regprocedure,
          'public.finalize_account_deletion(uuid)'::regprocedure
      )
        and prosecdef
        and array_to_string(proconfig, ',') in (
            'search_path=',
            'search_path=""'
        )$$,
    array[4::bigint],
    'all lifecycle commands are security definer with an empty search path'
);

select results_eq(
    $$select count(*)::bigint
      from pg_policies
      where schemaname = 'public'
        and tablename = 'companies'
        and cmd in ('INSERT', 'UPDATE', 'DELETE')
        and coalesce(qual, '') || coalesce(with_check, '')
            like '%account_is_active%'$$,
    array[0::bigint],
    'direct company mutation policies are removed'
);

select * from finish();
rollback;
