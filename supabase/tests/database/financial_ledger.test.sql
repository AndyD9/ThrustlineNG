begin;

select plan(24);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('51000000-0000-4000-8000-000000000001', 'ledger-a@thrustline.invalid', '{}'),
    ('52000000-0000-4000-8000-000000000002', 'ledger-b@thrustline.invalid', '{}'),
    ('53000000-0000-4000-8000-000000000003', 'ledger-replay@thrustline.invalid', '{}');

insert into public.companies (id, owner_id, name)
values
    ('f1000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', 'Ledger Alpha Air'),
    ('f2000000-0000-4000-8000-000000000002', '52000000-0000-4000-8000-000000000002', 'Ledger Bravo Air'),
    ('f3000000-0000-4000-8000-000000000003', '53000000-0000-4000-8000-000000000003', 'Ledger Replay Air');

select results_eq(
    $$select count(*)::bigint from private.financial_ledger_subjects
      where company_id in (
          'f1000000-0000-4000-8000-000000000001',
          'f2000000-0000-4000-8000-000000000002',
          'f3000000-0000-4000-8000-000000000003'
      )$$,
    array[3::bigint],
    'new companies receive opaque ledger subjects'
);

set local role authenticated;
select throws_ok(
    $$select public.post_company_opening_balance(
        'f1000000-0000-4000-8000-000000000001',
        'a1000000-0000-4000-8000-000000000001',
        25000000,
        'EUR'
    )$$,
    '42501',
    'permission denied for function post_company_opening_balance',
    'authenticated cannot post an opening balance'
);

reset role;
set local role service_role;

select is(
    public.post_company_opening_balance(
        'f1000000-0000-4000-8000-000000000001',
        'a1000000-0000-4000-8000-000000000001',
        25000000,
        'EUR'
    ) ->> 'amountMinor',
    '25000000',
    'service role posts the opening balance'
);

select is(
    public.post_company_opening_balance(
        'f1000000-0000-4000-8000-000000000001',
        'a1000000-0000-4000-8000-000000000001',
        25000000,
        'EUR'
    ) ->> 'sequenceNumber',
    '1',
    'an identical command replays idempotently'
);

reset role;

select results_eq(
    $$select count(*)::bigint from private.financial_ledger_entries$$,
    array[1::bigint],
    'idempotent replay creates one entry'
);

set local role service_role;

select throws_ok(
    $$select public.post_company_opening_balance(
        'f1000000-0000-4000-8000-000000000001',
        'a1000000-0000-4000-8000-000000000001',
        26000000,
        'EUR'
    )$$,
    '22023',
    'Idempotency key was already used with another payload.',
    'idempotency payload collision is rejected'
);

select throws_ok(
    $$select public.post_company_opening_balance(
        'f1000000-0000-4000-8000-000000000001',
        'a2000000-0000-4000-8000-000000000002',
        25000000,
        'EUR'
    )$$,
    '55000',
    'Company ledger is already open.',
    'a second opening is rejected'
);

select throws_ok(
    $$select public.post_company_opening_balance(
        'f2000000-0000-4000-8000-000000000002',
        'b1000000-0000-4000-8000-000000000001',
        0,
        'EUR'
    )$$,
    '22023',
    'Opening balance amount is invalid.',
    'zero amount is rejected'
);

select throws_ok(
    $$select public.post_company_opening_balance(
        'f2000000-0000-4000-8000-000000000002',
        'b1000000-0000-4000-8000-000000000001',
        100,
        'eur'
    )$$,
    '22023',
    'Currency code must be an uppercase ISO 4217 code.',
    'noncanonical currency is rejected'
);

select is(
    public.post_company_opening_balance(
        'f2000000-0000-4000-8000-000000000002',
        'b1000000-0000-4000-8000-000000000001',
        -5000,
        'USD'
    ) ->> 'currencyCode',
    'USD',
    'a bounded signed server amount is accepted'
);

reset role;

select set_config(
    'request.jwt.claims',
    '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',
    true
);
set local role authenticated;

select results_eq(
    $$select amount_minor, currency_code from public.get_company_ledger()$$,
    $$values (25000000::bigint, 'EUR'::text)$$,
    'A can read only company A ledger'
);

reset role;
select set_config(
    'request.jwt.claims',
    '{"sub":"52000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":false}',
    true
);
set local role authenticated;

select results_eq(
    $$select amount_minor, currency_code from public.get_company_ledger()$$,
    $$values (-5000::bigint, 'USD'::text)$$,
    'B can read only company B ledger'
);

reset role;
set local role anon;
select throws_ok(
    'select * from public.get_company_ledger()',
    '42501',
    'permission denied for function get_company_ledger',
    'anonymous cannot read a company ledger'
);

reset role;

select throws_ok(
    $$update private.financial_ledger_entries set amount_minor = 1$$,
    '55000',
    'Financial ledger entries are append-only.',
    'ledger entries cannot be updated'
);

select throws_ok(
    $$delete from private.financial_ledger_entries$$,
    '55000',
    'Financial ledger entries are append-only.',
    'ledger entries cannot be deleted'
);

select throws_ok(
    $$truncate private.financial_ledger_entries$$,
    '55000',
    'Financial ledger entries are append-only.',
    'ledger entries cannot be truncated'
);

insert into private.account_deletion_requests (
    id, owner_id, company_id, request_key, export_payload, export_sha256,
    requested_at, delete_after
)
values (
    'd1000000-0000-4000-8000-000000000001',
    '52000000-0000-4000-8000-000000000002',
    'f2000000-0000-4000-8000-000000000002',
    'd1100000-0000-4000-8000-000000000001',
    '{}'::jsonb,
    repeat('b', 64),
    statement_timestamp(),
    statement_timestamp() + interval '7 days'
);

set local role service_role;
select throws_ok(
    $$select public.post_company_opening_balance(
        'f2000000-0000-4000-8000-000000000002',
        'b2000000-0000-4000-8000-000000000002',
        100,
        'USD'
    )$$,
    '55000',
    'Company ledger cannot be changed.',
    'deletion pending blocks financial mutation'
);
reset role;

select set_config(
    't0020.replay_subject',
    (select subject_token::text from private.account_restoration_subjects
     where owner_id = '53000000-0000-4000-8000-000000000003'),
    true
);
select set_config(
    't0020.ledger_subject',
    (select subject_id::text from private.financial_ledger_subjects
     where company_id = 'f3000000-0000-4000-8000-000000000003'),
    true
);

set local role service_role;
select is(
    public.post_company_opening_balance(
        'f3000000-0000-4000-8000-000000000003',
        'c1000000-0000-4000-8000-000000000001',
        100000,
        'EUR'
    ) ->> 'entryType',
    'opening_balance',
    'replay owner receives an immutable opening entry'
);

select is(
    public.replay_account_deletion_event(
        current_setting('t0020.replay_subject')::uuid,
        repeat('c', 64),
        'c2000000-0000-4000-8000-000000000002',
        '2026-07-30 10:00:00+00',
        1,
        1
    ) ->> 'state',
    'deleted',
    'deletion replay completes with a ledger present'
);
reset role;

select results_eq(
    $$select company_id is null, anonymized_at is not null
      from private.financial_ledger_subjects
      where subject_id = current_setting('t0020.ledger_subject')::uuid$$,
    $$values (true, true)$$,
    'deletion replay detaches and dates the personal ledger link'
);

select results_eq(
    $$select count(*)::bigint from private.financial_ledger_entries
      where subject_id = current_setting('t0020.ledger_subject')::uuid
        and amount_minor = 100000 and currency_code = 'EUR'$$,
    array[1::bigint],
    'deletion replay preserves the immutable non-personal entry'
);

select results_eq(
    $$select count(*)::bigint from private.financial_ledger_entries$$,
    array[3::bigint],
    'negative scenarios leave exactly the three intended entries'
);

select ok(
    not exists (
        select 1 from information_schema.columns
        where table_schema = 'private'
          and table_name = 'financial_ledger_entries'
          and column_name in ('owner_id', 'company_id', 'company_name', 'email')
    ),
    'ledger entries contain no direct Auth or company identity column'
);

select results_eq(
    $$select count(*)::bigint from auth.users
      where id in (
          '51000000-0000-4000-8000-000000000001',
          '52000000-0000-4000-8000-000000000002'
      )$$,
    array[2::bigint],
    'unrelated owners remain intact'
);

select * from finish();
rollback;
