begin;

select plan(35);

insert into auth.users (id, email, raw_user_meta_data)
values
    (
        '41000000-0000-4000-8000-000000000001',
        'lifecycle-a@thrustline.invalid',
        '{}'
    ),
    (
        '42000000-0000-4000-8000-000000000002',
        'lifecycle-b@thrustline.invalid',
        '{}'
    ),
    (
        '43000000-0000-4000-8000-000000000003',
        'lifecycle-stale@thrustline.invalid',
        '{}'
    );

insert into auth.sessions (id, user_id, created_at, updated_at)
values
    (
        '41100000-0000-4000-8000-000000000001',
        '41000000-0000-4000-8000-000000000001',
        clock_timestamp(),
        clock_timestamp()
    ),
    (
        '42100000-0000-4000-8000-000000000002',
        '42000000-0000-4000-8000-000000000002',
        clock_timestamp(),
        clock_timestamp()
    ),
    (
        '43100000-0000-4000-8000-000000000003',
        '43000000-0000-4000-8000-000000000003',
        clock_timestamp() - interval '6 minutes',
        clock_timestamp() - interval '6 minutes'
    );

insert into public.companies (id, owner_id, name)
values
    (
        'd1000000-0000-4000-8000-000000000001',
        '41000000-0000-4000-8000-000000000001',
        'Lifecycle Alpha Air'
    ),
    (
        'd2000000-0000-4000-8000-000000000002',
        '42000000-0000-4000-8000-000000000002',
        'Lifecycle Bravo Air'
    ),
    (
        'd3000000-0000-4000-8000-000000000003',
        '43000000-0000-4000-8000-000000000003',
        'Lifecycle Stale Air'
    );

set local role authenticated;
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'role', 'authenticated',
        'sub', '41000000-0000-4000-8000-000000000001',
        'session_id', '41100000-0000-4000-8000-000000000001',
        'is_anonymous', false,
        'amr', jsonb_build_array(
            jsonb_build_object(
                'method', 'password',
                'timestamp', extract(epoch from clock_timestamp())
            )
        )
    )::text,
    true
);

select is(
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000001'
    ) ->> 'state',
    'deletion_pending',
    'A can request account deletion after recent reauthentication'
);

select is(
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000001'
    )::text,
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000001'
    )::text,
    'the same request key returns the same response'
);

select is(
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000002'
    ) ->> 'requestId',
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000001'
    ) ->> 'requestId',
    'a concurrent-equivalent second key converges on the pending request'
);

select throws_ok(
    $$update public.companies
      set name = 'Forbidden while pending'
      where owner_id = '41000000-0000-4000-8000-000000000001'$$,
    '42501',
    'permission denied for table companies',
    'direct company mutations are always blocked'
);

reset role;

select set_config(
    't0018.request_a',
    (
        select id::text
        from private.account_deletion_requests
        where owner_id = '41000000-0000-4000-8000-000000000001'
          and cancelled_at is null
    ),
    true
);

select is(
    (
        select export_payload ->> 'format'
        from private.account_deletion_requests
        where id = current_setting('t0018.request_a')::uuid
    ),
    'thrustline-account-export',
    'the portable export has an explicit format'
);

select is(
    (
        select export_payload ->> 'schemaVersion'
        from private.account_deletion_requests
        where id = current_setting('t0018.request_a')::uuid
    ),
    '1',
    'the portable export has schema version 1'
);

select is(
    (
        select export_payload #>> '{account,email}'
        from private.account_deletion_requests
        where id = current_setting('t0018.request_a')::uuid
    ),
    'lifecycle-a@thrustline.invalid',
    'A export contains only A account identity'
);

select is(
    (
        select export_payload #>> '{company,name}'
        from private.account_deletion_requests
        where id = current_setting('t0018.request_a')::uuid
    ),
    'Lifecycle Alpha Air',
    'A export contains A company'
);

select ok(
    (
        select export_payload::text not like '%lifecycle-b@thrustline.invalid%'
            and export_payload::text not like '%Lifecycle Bravo Air%'
        from private.account_deletion_requests
        where id = current_setting('t0018.request_a')::uuid
    ),
    'A export contains no B data'
);

select matches(
    (
        select export_sha256
        from private.account_deletion_requests
        where id = current_setting('t0018.request_a')::uuid
    ),
    '^[0-9a-f]{64}$',
    'the export has a SHA-256 integrity digest'
);

select is(
    (
        select delete_after - requested_at
        from private.account_deletion_requests
        where id = current_setting('t0018.request_a')::uuid
    ),
    interval '7 days',
    'the recovery window is exactly seven days'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'role', 'authenticated',
        'sub', '42000000-0000-4000-8000-000000000002',
        'session_id', '42100000-0000-4000-8000-000000000002',
        'is_anonymous', false,
        'amr', jsonb_build_array(
            jsonb_build_object(
                'method', 'password',
                'timestamp', extract(epoch from clock_timestamp())
            )
        )
    )::text,
    true
);

select throws_ok(
    format(
        'select public.get_account_export(%L::uuid)',
        current_setting('t0018.request_a')
    ),
    '42501',
    'Account lifecycle operation is not permitted.',
    'B cannot recover A export'
);

reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
    $$select public.request_account_deletion(
        'aa300000-0000-4000-8000-000000000001'
    )$$,
    '42501',
    'permission denied for function request_account_deletion',
    'anonymous cannot request account deletion'
);

reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'role', 'authenticated',
        'sub', '43000000-0000-4000-8000-000000000003',
        'session_id', '43100000-0000-4000-8000-000000000003',
        'is_anonymous', false,
        'amr', jsonb_build_array(
            jsonb_build_object(
                'method', 'password',
                'timestamp', extract(epoch from clock_timestamp())
            )
        )
    )::text,
    true
);

select throws_ok(
    $$select public.request_account_deletion(
        'aa300000-0000-4000-8000-000000000002'
    )$$,
    '42501',
    'Recent reauthentication is required.',
    'a session older than five minutes is rejected'
);

reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'role', 'authenticated',
        'sub', '42000000-0000-4000-8000-000000000002',
        'session_id', '42100000-0000-4000-8000-000000000002',
        'is_anonymous', false,
        'amr', jsonb_build_array(
            jsonb_build_object(
                'method', 'token_refresh',
                'timestamp', extract(epoch from clock_timestamp())
            )
        )
    )::text,
    true
);

select throws_ok(
    $$select public.request_account_deletion(
        'aa200000-0000-4000-8000-000000000001'
    )$$,
    '42501',
    'Recent reauthentication is required.',
    'a token refresh is not accepted as reauthentication'
);

select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'role', 'authenticated',
        'sub', '41000000-0000-4000-8000-000000000001',
        'session_id', '41100000-0000-4000-8000-000000000001',
        'is_anonymous', false,
        'amr', jsonb_build_array(
            jsonb_build_object(
                'method', 'password',
                'timestamp', extract(epoch from clock_timestamp())
            )
        )
    )::text,
    true
);

select is(
    public.get_account_export(
        current_setting('t0018.request_a')::uuid
    ) ->> 'exportSha256',
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000001'
    ) ->> 'exportSha256',
    'A can recover the same export after a lost response'
);

select is(
    public.cancel_account_deletion(
        current_setting('t0018.request_a')::uuid,
        'ac100000-0000-4000-8000-000000000001'
    ) ->> 'state',
    'active',
    'A can cancel during the recovery window'
);

select is(
    public.cancel_account_deletion(
        current_setting('t0018.request_a')::uuid,
        'ac100000-0000-4000-8000-000000000001'
    )::text,
    public.cancel_account_deletion(
        current_setting('t0018.request_a')::uuid,
        'ac100000-0000-4000-8000-000000000001'
    )::text,
    'cancellation is idempotent'
);

select is(
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000001'
    ) ->> 'state',
    'active',
    'a cancelled request replay cannot recover a deleted export'
);

select throws_ok(
    $$update public.companies
      set name = 'Lifecycle Alpha Restored'
      where owner_id = '41000000-0000-4000-8000-000000000001'$$,
    '42501',
    'permission denied for table companies',
    'direct company mutation remains blocked after cancellation'
);

select is(
    public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000003'
    ) ->> 'state',
    'deletion_pending',
    'A can create a new request after cancellation'
);

select throws_ok(
    $$select public.cancel_account_deletion(
        (
            public.request_account_deletion(
                'aa100000-0000-4000-8000-000000000003'
            ) ->> 'requestId'
        )::uuid,
        'ac100000-0000-4000-8000-000000000001'
    )$$,
    '22023',
    'Idempotency key was already used for another request.',
    'a cancellation key cannot be reused for another request'
);

reset role;

select set_config(
    't0018.request_final',
    (
        select id::text
        from private.account_deletion_requests
        where owner_id = '41000000-0000-4000-8000-000000000001'
          and cancelled_at is null
    ),
    true
);

update private.account_deletion_requests
set requested_at = statement_timestamp() - interval '8 days',
    delete_after = statement_timestamp() - interval '1 day'
where id = current_setting('t0018.request_final')::uuid;

set local role authenticated;

select throws_ok(
    $$select public.request_account_deletion(
        'aa100000-0000-4000-8000-000000000003'
    )$$,
    '55000',
    'Account deletion is awaiting server finalization.',
    'an expired idempotent replay cannot recover the export'
);

select throws_ok(
    format(
        'select public.finalize_account_deletion(%L::uuid)',
        current_setting('t0018.request_final')
    ),
    '42501',
    'permission denied for function finalize_account_deletion',
    'authenticated cannot invoke finalization'
);

reset role;

create function public.t0018_inject_auth_delete_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if old.id = '41000000-0000-4000-8000-000000000001'::uuid then
        raise exception 'Injected finalization failure.';
    end if;
    return old;
end;
$$;

create trigger t0018_inject_auth_delete_failure
before delete on auth.users
for each row
execute function public.t0018_inject_auth_delete_failure();

set local role service_role;

select throws_ok(
    format(
        'select public.finalize_account_deletion(%L::uuid)',
        current_setting('t0018.request_final')
    ),
    'P0001',
    'Injected finalization failure.',
    'an injected finalization failure rolls back the command'
);

reset role;

select results_eq(
    $$select count(*)::bigint
      from auth.users
      where id = '41000000-0000-4000-8000-000000000001'$$,
    array[1::bigint],
    'rollback preserves the Auth owner'
);

select results_eq(
    $$select count(*)::bigint
      from public.companies
      where owner_id = '41000000-0000-4000-8000-000000000001'$$,
    array[1::bigint],
    'rollback preserves the company'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_requests
      where id = current_setting('t0018.request_final')::uuid$$,
    array[1::bigint],
    'rollback preserves the pending request'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_markers$$,
    array[0::bigint],
    'rollback leaves no false completion marker'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_replay_events$$,
    array[0::bigint],
    'rollback leaves no false deletion replay event'
);

drop trigger t0018_inject_auth_delete_failure on auth.users;
drop function public.t0018_inject_auth_delete_failure();

set local role service_role;

select is(
    public.finalize_account_deletion(
        current_setting('t0018.request_final')::uuid
    ) ->> 'state',
    'deleted',
    'the service role finalizes an expired request'
);

reset role;

select set_config(
    't0018.marker_id',
    (
        select marker_id::text
        from private.account_deletion_markers
    ),
    true
);

set local role service_role;

select is(
    public.finalize_account_deletion(
        current_setting('t0018.request_final')::uuid
    ) ->> 'markerId',
    current_setting('t0018.marker_id'),
    'finalization replay returns the same non-personal marker'
);

reset role;

select results_eq(
    $$select
          (select count(*) from auth.users
           where id = '41000000-0000-4000-8000-000000000001')::bigint,
          (select count(*) from public.companies
           where owner_id = '41000000-0000-4000-8000-000000000001')::bigint,
          (select count(*) from private.account_deletion_requests
           where owner_id = '41000000-0000-4000-8000-000000000001')::bigint,
          (select count(*) from private.account_lifecycle_commands
           where owner_id = '41000000-0000-4000-8000-000000000001')::bigint$$,
    $$values (0::bigint, 0::bigint, 0::bigint, 0::bigint)$$,
    'finalization removes Auth, company, export request, and command linkage'
);

select ok(
    (
        select row_to_json(markers)::text
            not like '%41000000-0000-4000-8000-000000000001%'
            and row_to_json(markers)::text
            not like '%lifecycle-a@thrustline.invalid%'
            and row_to_json(markers)::text
            not like '%Lifecycle Alpha%'
        from private.account_deletion_markers as markers
    ),
    'the completion marker contains no direct identity or exported content'
);

select results_eq(
    $$select count(*)::bigint
      from private.account_deletion_replay_events as events
      join private.account_deletion_markers as markers
        on markers.request_token_hash = events.request_token_hash
       and markers.marker_id = events.marker_id
       and markers.completed_at = events.completed_at
       and markers.export_schema_version = events.export_schema_version
      where events.event_schema_version = 1$$,
    array[1::bigint],
    'finalization atomically records one versioned deletion replay event'
);

select * from finish();
rollback;
