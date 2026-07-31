begin;

select plan(15);

select has_table(
    'private',
    'account_restoration_subjects',
    'private restoration subject table exists'
);

select has_table(
    'private',
    'account_deletion_replay_events',
    'private deletion replay event table exists'
);

select results_eq(
    $$select count(*)::bigint
      from pg_class
      where oid in (
          'private.account_restoration_subjects'::regclass,
          'private.account_deletion_replay_events'::regclass
      )
        and relrowsecurity
        and relforcerowsecurity$$,
    array[2::bigint],
    'both restoration tables enable and force RLS'
);

select results_eq(
    $$select count(*)::bigint
      from information_schema.role_table_grants
      where table_schema = 'private'
        and table_name in (
            'account_restoration_subjects',
            'account_deletion_replay_events'
        )
        and grantee in ('anon', 'authenticated')$$,
    array[0::bigint],
    'API roles have no restoration table privileges'
);

select col_is_pk(
    'private',
    'account_restoration_subjects',
    'subject_token',
    'the opaque subject token is the restoration key'
);

select col_is_unique(
    'private',
    'account_restoration_subjects',
    'owner_id',
    'one restoration subject exists per owner'
);

select col_is_unique(
    'private',
    'account_restoration_subjects',
    'company_id',
    'one restoration subject exists per company'
);

select has_trigger(
    'public',
    'companies',
    'companies_create_restoration_subject',
    'future companies receive a restoration subject'
);

select has_function(
    'public',
    'replay_account_deletion_event',
    array['uuid', 'text', 'uuid', 'timestamp with time zone', 'integer', 'integer'],
    'privileged deletion replay command exists'
);

select ok(
    has_function_privilege(
        'service_role',
        'public.replay_account_deletion_event(uuid,text,uuid,timestamptz,integer,integer)',
        'EXECUTE'
    ),
    'service role can replay a deletion event'
);

select ok(
    not has_function_privilege(
        'authenticated',
        'public.replay_account_deletion_event(uuid,text,uuid,timestamptz,integer,integer)',
        'EXECUTE'
    ),
    'authenticated cannot replay a deletion event'
);

select ok(
    not has_function_privilege(
        'anon',
        'public.replay_account_deletion_event(uuid,text,uuid,timestamptz,integer,integer)',
        'EXECUTE'
    ),
    'anonymous cannot replay a deletion event'
);

select results_eq(
    $$select count(*)::bigint
      from pg_proc
      where oid in (
          'private.create_account_restoration_subject()'::regprocedure,
          'public.replay_account_deletion_event(uuid,text,uuid,timestamptz,integer,integer)'::regprocedure,
          'public.finalize_account_deletion(uuid)'::regprocedure
      )
        and prosecdef
        and array_to_string(proconfig, ',') in (
            'search_path=',
            'search_path=""'
        )$$,
    array[3::bigint],
    'restoration functions are security definer with an empty search path'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_restoration_subjects$$,
    $$select count(*)::bigint
      from public.companies$$,
    'the migration backfills every existing company'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_replay_events
      where request_token_hash !~ '^[0-9a-f]{64}$'
         or export_schema_version <> 1
         or event_schema_version <> 1$$,
    array[0::bigint],
    'existing replay events satisfy the versioned pseudonymous format'
);

select * from finish();
rollback;
