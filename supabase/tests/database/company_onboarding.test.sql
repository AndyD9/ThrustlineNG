begin;

select plan(29);

insert into auth.users (id, email, raw_user_meta_data, is_anonymous)
values
    ('61000000-0000-4000-8000-000000000001', 'onboarding-a@thrustline.invalid', '{}', false),
    ('62000000-0000-4000-8000-000000000002', 'onboarding-b@thrustline.invalid', '{}', false),
    ('63000000-0000-4000-8000-000000000003', null, '{}', true),
    ('64000000-0000-4000-8000-000000000004', 'onboarding-rollback@thrustline.invalid', '{}', false),
    ('68000000-0000-4000-8000-000000000008', 'onboarding-pending@thrustline.invalid', '{}', false);

insert into auth.sessions (id, user_id, created_at, updated_at)
values (
    '68100000-0000-4000-8000-000000000008',
    '68000000-0000-4000-8000-000000000008',
    clock_timestamp(),
    clock_timestamp()
);

insert into public.companies (owner_id, name)
values (
    '68000000-0000-4000-8000-000000000008',
    'Pending Onboarding Air'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"role":"authenticated","sub":"61000000-0000-4000-8000-000000000001"}',
    true
);

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '61000000-0000-4000-8000-000000000001',
        'ba100000-0000-4000-8000-000000000001',
        'Onboarding Alpha Air',
        50000000,
        'EUR'
    )$$,
    '42501',
    'permission denied for function create_company_with_opening_balance',
    'authenticated cannot create a company through the server command'
);

select throws_ok(
    $$insert into public.companies (owner_id, name)
      values ('61000000-0000-4000-8000-000000000001', 'Direct Alpha Air')$$,
    '42501',
    'permission denied for table companies',
    'authenticated cannot insert a company directly'
);

reset role;
set local role service_role;

select set_config(
    't0022.response',
    public.create_company_with_opening_balance(
        '61000000-0000-4000-8000-000000000001',
        'ba100000-0000-4000-8000-000000000001',
        'Onboarding Alpha Air',
        50000000,
        'EUR'
    )::text,
    true
);

reset role;

select is(
    current_setting('t0022.response')::jsonb ->> 'schemaVersion',
    '1',
    'onboarding returns schema version 1'
);

select is(
    current_setting('t0022.response')::jsonb ->> 'state',
    'active',
    'onboarding returns an active company'
);

select results_eq(
    $$select name from public.companies
      where owner_id = '61000000-0000-4000-8000-000000000001'$$,
    array['Onboarding Alpha Air'::text],
    'authoritative onboarding creates the company'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_restoration_subjects as subjects
      join public.companies as companies on companies.id = subjects.company_id
      where companies.owner_id = '61000000-0000-4000-8000-000000000001'$$,
    array[1::bigint],
    'onboarding creates the restoration subject atomically'
);

select results_eq(
    $$select count(*)::bigint
      from private.financial_ledger_subjects as subjects
      join public.companies as companies on companies.id = subjects.company_id
      where companies.owner_id = '61000000-0000-4000-8000-000000000001'$$,
    array[1::bigint],
    'onboarding creates the financial subject atomically'
);

select results_eq(
    $$select entries.amount_minor, entries.currency_code
      from private.financial_ledger_entries as entries
      join private.financial_ledger_subjects as subjects using (subject_id)
      join public.companies as companies on companies.id = subjects.company_id
      where companies.owner_id = '61000000-0000-4000-8000-000000000001'$$,
    $$values (50000000::bigint, 'EUR'::text)$$,
    'onboarding creates exactly the requested opening entry'
);

set local role service_role;

select is(
    public.create_company_with_opening_balance(
        '61000000-0000-4000-8000-000000000001',
        'ba100000-0000-4000-8000-000000000001',
        'Onboarding Alpha Air',
        50000000,
        'EUR'
    )::text,
    current_setting('t0022.response'),
    'an identical onboarding command replays idempotently'
);

reset role;

select results_eq(
    $$select count(*)::bigint
      from private.company_onboarding_commands
      where owner_id = '61000000-0000-4000-8000-000000000001'$$,
    array[1::bigint],
    'idempotent replay keeps one onboarding command'
);

set local role service_role;

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '61000000-0000-4000-8000-000000000001',
        'ba100000-0000-4000-8000-000000000001',
        'Onboarding Alpha Changed',
        50000000,
        'EUR'
    )$$,
    '22023',
    'Idempotency key was already used with a different payload.',
    'onboarding idempotency payload collision is rejected'
);

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '61000000-0000-4000-8000-000000000001',
        'ba100000-0000-4000-8000-000000000002',
        'Onboarding Alpha Air',
        50000000,
        'EUR'
    )$$,
    '55000',
    'Company already exists.',
    'a second onboarding key cannot create another company'
);

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '63000000-0000-4000-8000-000000000003',
        'ba300000-0000-4000-8000-000000000003',
        'Anonymous Air',
        50000000,
        'EUR'
    )$$,
    '42501',
    'Company owner is not eligible.',
    'an anonymous Auth identity cannot own a company'
);

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '65000000-0000-4000-8000-000000000005',
        'ba500000-0000-4000-8000-000000000005',
        'Missing Owner Air',
        50000000,
        'EUR'
    )$$,
    '42501',
    'Company owner is not eligible.',
    'a missing Auth identity cannot own a company'
);

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '62000000-0000-4000-8000-000000000002',
        'ba200000-0000-4000-8000-000000000002',
        ' Untrimmed Air ',
        50000000,
        'EUR'
    )$$,
    '22023',
    'Company name must be trimmed and contain between 2 and 80 characters.',
    'an untrimmed company name is rejected'
);

reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'role', 'authenticated',
        'sub', '68000000-0000-4000-8000-000000000008',
        'session_id', '68100000-0000-4000-8000-000000000008',
        'is_anonymous', false,
        'amr', jsonb_build_array(
            jsonb_build_object(
                'method', 'password',
                'timestamp', floor(extract(epoch from clock_timestamp()))::bigint
            )
        )
    )::text,
    true
);
select public.request_account_deletion(
    'aa800000-0000-4000-8000-000000000008'
);
reset role;
set local role service_role;

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '68000000-0000-4000-8000-000000000008',
        'ba800000-0000-4000-8000-000000000008',
        'Pending Onboarding Air',
        50000000,
        'EUR'
    )$$,
    '55000',
    'Account deletion is pending.',
    'deletion pending blocks company onboarding'
);

select public.create_company_with_opening_balance(
    '62000000-0000-4000-8000-000000000002',
    'ba200000-0000-4000-8000-000000000002',
    'Onboarding Bravo Air',
    60000000,
    'USD'
);

reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"role":"authenticated","sub":"61000000-0000-4000-8000-000000000001"}',
    true
);

select results_eq(
    $$select name from public.companies order by name$$,
    array['Onboarding Alpha Air'::text],
    'A can read only company A after onboarding'
);

select results_eq(
    $$select amount_minor, currency_code from public.get_company_ledger()$$,
    $$values (50000000::bigint, 'EUR'::text)$$,
    'A can read only A opening entry after onboarding'
);

select throws_ok(
    $$update public.companies set name = 'Direct Rename'$$,
    '42501',
    'permission denied for table companies',
    'authenticated cannot update a company directly'
);

select throws_ok(
    $$delete from public.companies$$,
    '42501',
    'permission denied for table companies',
    'authenticated cannot delete a company directly'
);

reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"role":"authenticated","sub":"62000000-0000-4000-8000-000000000002"}',
    true
);

select results_eq(
    $$select name from public.companies order by name$$,
    array['Onboarding Bravo Air'::text],
    'B can read only company B after onboarding'
);

select results_eq(
    $$select amount_minor, currency_code from public.get_company_ledger()$$,
    $$values (60000000::bigint, 'USD'::text)$$,
    'B can read only B opening entry after onboarding'
);

reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
    $$select * from public.companies$$,
    '42501',
    'permission denied for table companies',
    'anonymous cannot read companies after onboarding hardening'
);

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '62000000-0000-4000-8000-000000000002',
        'ba200000-0000-4000-8000-000000000099',
        'Forged Bravo Air',
        1,
        'USD'
    )$$,
    '42501',
    'permission denied for function create_company_with_opening_balance',
    'anonymous cannot invoke onboarding'
);

reset role;

create function public.t0022_inject_opening_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception 'Injected onboarding failure.';
end;
$$;

create trigger t0022_inject_opening_failure
before insert on private.financial_ledger_entries
for each row
execute function public.t0022_inject_opening_failure();

set local role service_role;

select throws_ok(
    $$select public.create_company_with_opening_balance(
        '64000000-0000-4000-8000-000000000004',
        'ba400000-0000-4000-8000-000000000004',
        'Rollback Air',
        70000000,
        'EUR'
    )$$,
    'P0001',
    'Injected onboarding failure.',
    'an injected opening failure rolls back onboarding'
);

reset role;

select results_eq(
    $$select count(*)::bigint from public.companies
      where owner_id = '64000000-0000-4000-8000-000000000004'$$,
    array[0::bigint],
    'rollback leaves no company'
);

select results_eq(
    $$select count(*)::bigint from private.account_restoration_subjects
      where owner_id = '64000000-0000-4000-8000-000000000004'$$,
    array[0::bigint],
    'rollback leaves no restoration subject'
);

select results_eq(
    $$select count(*)::bigint from private.company_onboarding_commands
      where owner_id = '64000000-0000-4000-8000-000000000004'$$,
    array[0::bigint],
    'rollback leaves no onboarding command'
);

select results_eq(
    $$select count(*)::bigint from private.financial_ledger_entries as entries
      join private.financial_ledger_subjects as subjects using (subject_id)
      where subjects.company_id in (
          select id from public.companies
          where owner_id = '64000000-0000-4000-8000-000000000004'
      )$$,
    array[0::bigint],
    'rollback leaves no financial entry'
);

drop trigger t0022_inject_opening_failure on private.financial_ledger_entries;
drop function public.t0022_inject_opening_failure();

select * from finish();
rollback;
