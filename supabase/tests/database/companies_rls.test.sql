begin;

select plan(12);

insert into auth.users (id, email, raw_user_meta_data)
values
    (
        '31000000-0000-4000-8000-000000000001',
        'rls-a@thrustline.invalid',
        '{}'
    ),
    (
        '32000000-0000-4000-8000-000000000002',
        'rls-b@thrustline.invalid',
        '{}'
    );

insert into public.companies (id, owner_id, name)
values
    (
        'c1000000-0000-4000-8000-000000000001',
        '31000000-0000-4000-8000-000000000001',
        'RLS Alpha Air'
    ),
    (
        'c2000000-0000-4000-8000-000000000002',
        '32000000-0000-4000-8000-000000000002',
        'RLS Bravo Air'
    );

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"role":"authenticated","sub":"31000000-0000-4000-8000-000000000001"}',
    true
);

select results_eq(
    $$select owner_id
      from public.companies
      order by owner_id$$,
    array['31000000-0000-4000-8000-000000000001'::uuid],
    'A can read only company A'
);

select throws_ok(
    $$update public.companies
      set name = 'RLS Alpha Updated'
      where owner_id = '31000000-0000-4000-8000-000000000001'$$,
    '42501',
    'permission denied for table companies',
    'A cannot update company A directly'
);

select throws_ok(
    $$update public.companies
      set name = 'Forbidden update'
      where owner_id = '32000000-0000-4000-8000-000000000002'$$,
    '42501',
    'permission denied for table companies',
    'A cannot update company B'
);

select throws_ok(
    $$delete from public.companies
      where owner_id = '32000000-0000-4000-8000-000000000002'$$,
    '42501',
    'permission denied for table companies',
    'A cannot delete company B'
);

select throws_ok(
    $$insert into public.companies (owner_id, name)
      values (
          '32000000-0000-4000-8000-000000000002',
          'Forged ownership'
      )$$,
    '42501',
    'permission denied for table companies',
    'A cannot create a company owned by B'
);

select throws_ok(
    $$insert into public.companies (owner_id, name)
      values (
          '31000000-0000-4000-8000-000000000001',
          'Second Alpha'
      )$$,
    '42501',
    'permission denied for table companies',
    'A cannot own two companies'
);

reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"role":"authenticated","sub":"32000000-0000-4000-8000-000000000002"}',
    true
);

select results_eq(
    $$select owner_id
      from public.companies
      order by owner_id$$,
    array['32000000-0000-4000-8000-000000000002'::uuid],
    'B can read only company B'
);

select throws_ok(
    $$update public.companies
      set name = 'Forbidden update'
      where owner_id = '31000000-0000-4000-8000-000000000001'$$,
    '42501',
    'permission denied for table companies',
    'B cannot update company A'
);

reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
    $$select * from public.companies$$,
    '42501',
    'permission denied for table companies',
    'anonymous cannot read companies'
);

select throws_ok(
    $$insert into public.companies (owner_id, name)
      values (
          '31000000-0000-4000-8000-000000000001',
          'Anonymous Air'
      )$$,
    '42501',
    'permission denied for table companies',
    'anonymous cannot insert companies'
);

select throws_ok(
    $$update public.companies set name = 'Anonymous update'$$,
    '42501',
    'permission denied for table companies',
    'anonymous cannot update companies'
);

select throws_ok(
    $$delete from public.companies$$,
    '42501',
    'permission denied for table companies',
    'anonymous cannot delete companies'
);

select * from finish();
rollback;
