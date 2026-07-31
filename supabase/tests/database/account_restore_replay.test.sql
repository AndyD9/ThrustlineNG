begin;

select plan(18);

insert into auth.users (id, email, raw_user_meta_data)
values
    (
        '45000000-0000-4000-8000-000000000005',
        'restore-a@thrustline.invalid',
        '{}'
    ),
    (
        '46000000-0000-4000-8000-000000000006',
        'restore-b@thrustline.invalid',
        '{}'
    ),
    (
        '47000000-0000-4000-8000-000000000007',
        'restore-rollback@thrustline.invalid',
        '{}'
    );

insert into public.companies (id, owner_id, name)
values
    (
        'd5000000-0000-4000-8000-000000000005',
        '45000000-0000-4000-8000-000000000005',
        'Restore Alpha Air'
    ),
    (
        'd6000000-0000-4000-8000-000000000006',
        '46000000-0000-4000-8000-000000000006',
        'Restore Bravo Air'
    ),
    (
        'd7000000-0000-4000-8000-000000000007',
        '47000000-0000-4000-8000-000000000007',
        'Restore Rollback Air'
    );

select results_eq(
    $$select count(*)::bigint
      from private.account_restoration_subjects
      where owner_id in (
          '45000000-0000-4000-8000-000000000005',
          '46000000-0000-4000-8000-000000000006',
          '47000000-0000-4000-8000-000000000007'
      )$$,
    array[3::bigint],
    'every new company receives one restoration subject'
);

select results_eq(
    $$select count(distinct subject_token)::bigint
      from private.account_restoration_subjects
      where owner_id in (
          '45000000-0000-4000-8000-000000000005',
          '46000000-0000-4000-8000-000000000006',
          '47000000-0000-4000-8000-000000000007'
      )$$,
    array[3::bigint],
    'restoration subjects use distinct opaque tokens'
);

select set_config(
    't0019.subject_a',
    (
        select subject_token::text
        from private.account_restoration_subjects
        where owner_id = '45000000-0000-4000-8000-000000000005'
    ),
    true
);

select set_config(
    't0019.subject_rollback',
    (
        select subject_token::text
        from private.account_restoration_subjects
        where owner_id = '47000000-0000-4000-8000-000000000007'
    ),
    true
);

set local role authenticated;

select throws_ok(
    format(
        'select public.replay_account_deletion_event(%L::uuid, %L, %L::uuid, statement_timestamp() - interval ''1 day'', 1, 1)',
        current_setting('t0019.subject_a'),
        repeat('a', 64),
        'e5000000-0000-4000-8000-000000000005'
    ),
    '42501',
    'permission denied for function replay_account_deletion_event',
    'authenticated cannot invoke deletion replay'
);

reset role;
set local role service_role;

select is(
    public.replay_account_deletion_event(
        current_setting('t0019.subject_a')::uuid,
        repeat('a', 64),
        'e5000000-0000-4000-8000-000000000005',
        '2026-07-31 10:00:00+00',
        1,
        1
    ) ->> 'state',
    'deleted',
    'service role replays a valid deletion event'
);

reset role;

select results_eq(
    $$select
          (select count(*) from auth.users
           where id = '45000000-0000-4000-8000-000000000005')::bigint,
          (select count(*) from public.companies
           where owner_id = '45000000-0000-4000-8000-000000000005')::bigint,
          (select count(*) from private.account_restoration_subjects
           where owner_id = '45000000-0000-4000-8000-000000000005')::bigint$$,
    $$values (0::bigint, 0::bigint, 0::bigint)$$,
    'replay removes the restored Auth owner, company, and private mapping'
);

select results_eq(
    $$select
          (select count(*) from auth.users
           where id = '46000000-0000-4000-8000-000000000006')::bigint,
          (select count(*) from public.companies
           where owner_id = '46000000-0000-4000-8000-000000000006')::bigint,
          (select count(*) from private.account_restoration_subjects
           where owner_id = '46000000-0000-4000-8000-000000000006')::bigint$$,
    $$values (1::bigint, 1::bigint, 1::bigint)$$,
    'replay preserves the unrelated owner B'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_replay_events
      where subject_token = current_setting('t0019.subject_a')::uuid
        and request_token_hash = repeat('a', 64)
        and marker_id = 'e5000000-0000-4000-8000-000000000005'
        and export_schema_version = 1
        and event_schema_version = 1$$,
    array[1::bigint],
    'replay records the exact versioned event'
);

select ok(
    (
        select row_to_json(events)::text
            not like '%45000000-0000-4000-8000-000000000005%'
            and row_to_json(events)::text
            not like '%restore-a@thrustline.invalid%'
            and row_to_json(events)::text
            not like '%Restore Alpha Air%'
        from private.account_deletion_replay_events as events
        where events.subject_token = current_setting('t0019.subject_a')::uuid
    ),
    'the pseudonymous replay event contains no direct Auth id, email, or company name'
);

set local role service_role;

select is(
    public.replay_account_deletion_event(
        current_setting('t0019.subject_a')::uuid,
        repeat('a', 64),
        'e5000000-0000-4000-8000-000000000005',
        '2026-07-31 10:00:00+00',
        1,
        1
    ) ->> 'markerId',
    'e5000000-0000-4000-8000-000000000005',
    'the same event replays idempotently'
);

select throws_ok(
    format(
        'select public.replay_account_deletion_event(%L::uuid, %L, %L::uuid, %L::timestamptz, 1, 1)',
        current_setting('t0019.subject_a'),
        repeat('a', 64),
        'e5000000-0000-4000-8000-000000000099',
        '2026-07-31 10:00:00+00'
    ),
    '22023',
    'Deletion replay event conflicts with the recorded event.',
    'an altered replay event is rejected'
);

select throws_ok(
    $$select public.replay_account_deletion_event(
        'e9000000-0000-4000-8000-000000000009',
        repeat('9', 64),
        'e9000000-0000-4000-8000-000000000099',
        '2026-07-31 10:00:00+00',
        1,
        1
    )$$,
    '55000',
    'Deletion replay event does not match the restored backup.',
    'an unknown replay subject fails closed'
);

reset role;

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_replay_events$$,
    array[1::bigint],
    'rejected events leave no additional replay record'
);

create function public.t0019_inject_auth_delete_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if old.id = '47000000-0000-4000-8000-000000000007'::uuid then
        raise exception 'Injected replay failure.';
    end if;
    return old;
end;
$$;

create trigger t0019_inject_auth_delete_failure
before delete on auth.users
for each row
execute function public.t0019_inject_auth_delete_failure();

set local role service_role;

select throws_ok(
    format(
        'select public.replay_account_deletion_event(%L::uuid, %L, %L::uuid, %L::timestamptz, 1, 1)',
        current_setting('t0019.subject_rollback'),
        repeat('7', 64),
        'e7000000-0000-4000-8000-000000000007',
        '2026-07-31 10:00:00+00'
    ),
    'P0001',
    'Injected replay failure.',
    'an injected replay failure rolls back the transaction'
);

reset role;

select results_eq(
    $$select
          (select count(*) from auth.users
           where id = '47000000-0000-4000-8000-000000000007')::bigint,
          (select count(*) from public.companies
           where owner_id = '47000000-0000-4000-8000-000000000007')::bigint,
          (select count(*) from private.account_restoration_subjects
           where owner_id = '47000000-0000-4000-8000-000000000007')::bigint$$,
    $$values (1::bigint, 1::bigint, 1::bigint)$$,
    'rollback preserves the restored owner, company, and private mapping'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_replay_events
      where subject_token = current_setting('t0019.subject_rollback')::uuid$$,
    array[0::bigint],
    'rollback leaves no false replay event'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_markers
      where marker_id = 'e7000000-0000-4000-8000-000000000007'$$,
    array[0::bigint],
    'rollback leaves no false deletion marker'
);

drop trigger t0019_inject_auth_delete_failure on auth.users;
drop function public.t0019_inject_auth_delete_failure();

select throws_ok(
    format(
        'select public.replay_account_deletion_event(%L::uuid, %L, %L::uuid, clock_timestamp() + interval ''1 day'', 1, 1)',
        current_setting('t0019.subject_rollback'),
        repeat('7', 64),
        'e7000000-0000-4000-8000-000000000007'
    ),
    '22023',
    'Deletion replay event is invalid.',
    'a future-dated replay event is rejected'
);

select results_eq(
    $$select count(*)::bigint
      from auth.users
      where id = '46000000-0000-4000-8000-000000000006'$$,
    array[1::bigint],
    'owner B remains intact after all negative replay scenarios'
);

select * from finish();
rollback;
