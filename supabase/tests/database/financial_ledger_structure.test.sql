begin;

select plan(19);

select has_table('private', 'financial_ledger_subjects', 'private ledger subjects exist');
select has_table('private', 'financial_ledger_entries', 'private ledger entries exist');

select results_eq(
    $$select count(*)::bigint from pg_class
      where oid in (
          'private.financial_ledger_subjects'::regclass,
          'private.financial_ledger_entries'::regclass
      ) and relrowsecurity and relforcerowsecurity$$,
    array[2::bigint],
    'ledger tables enable and force RLS'
);

select results_eq(
    $$select count(*)::bigint from information_schema.role_table_grants
      where table_schema = 'private'
        and table_name in ('financial_ledger_subjects', 'financial_ledger_entries')
        and grantee in ('anon', 'authenticated')$$,
    array[0::bigint],
    'API roles have no direct ledger table privileges'
);

select col_is_pk('private', 'financial_ledger_subjects', 'subject_id', 'subject UUID is primary key');
select col_is_unique('private', 'financial_ledger_subjects', 'company_id', 'one subject maps to a company');
select col_is_pk('private', 'financial_ledger_entries', 'id', 'entry UUID is primary key');

select has_trigger('public', 'companies', 'companies_create_financial_ledger_subject', 'new companies receive a ledger subject');
select has_trigger('public', 'companies', 'companies_anonymize_financial_ledger_subject', 'company deletion detaches the ledger subject');
select has_trigger('private', 'financial_ledger_entries', 'financial_ledger_entries_reject_update_delete', 'entry updates and deletes are rejected');
select has_trigger('private', 'financial_ledger_entries', 'financial_ledger_entries_reject_truncate', 'entry truncation is rejected');

select has_function(
    'public',
    'post_company_opening_balance',
    array['uuid', 'uuid', 'bigint', 'text'],
    'server opening command exists'
);
select has_function('public', 'get_company_ledger', array[]::text[], 'owner ledger read exists');

select ok(
    has_function_privilege('service_role', 'public.post_company_opening_balance(uuid,uuid,bigint,text)', 'EXECUTE'),
    'service role can post an opening balance'
);
select ok(
    not has_function_privilege('authenticated', 'public.post_company_opening_balance(uuid,uuid,bigint,text)', 'EXECUTE'),
    'authenticated cannot post an opening balance'
);
select ok(
    has_function_privilege('authenticated', 'public.get_company_ledger()', 'EXECUTE'),
    'authenticated can read its ledger'
);
select ok(
    not has_function_privilege('anon', 'public.get_company_ledger()', 'EXECUTE'),
    'anonymous cannot read a ledger'
);

select results_eq(
    $$select count(*)::bigint from pg_proc
      where oid in (
          'private.create_financial_ledger_subject()'::regprocedure,
          'private.anonymize_financial_ledger_subject()'::regprocedure,
          'public.post_company_opening_balance(uuid,uuid,bigint,text)'::regprocedure,
          'public.get_company_ledger()'::regprocedure
      ) and prosecdef
        and array_to_string(proconfig, ',') in ('search_path=', 'search_path=""')$$,
    array[4::bigint],
    'ledger boundary functions are security definer with empty search paths'
);

select results_eq(
    $$select count(*)::bigint from private.financial_ledger_subjects$$,
    $$select count(*)::bigint from public.companies$$,
    'the migration backfills every company'
);

select * from finish();
rollback;
