-- Synthetic local identities. They have no password and cannot sign in.
insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    is_anonymous
)
values
    (
        '00000000-0000-0000-0000-000000000000',
        '10000000-0000-4000-8000-000000000001',
        'authenticated',
        'authenticated',
        'pilot-a@thrustline.invalid',
        '',
        '2026-07-28 00:00:00+00',
        '{"provider":"email","providers":["email"]}',
        '{}',
        '2026-07-28 00:00:00+00',
        '2026-07-28 00:00:00+00',
        '',
        '',
        '',
        '',
        false
    ),
    (
        '00000000-0000-0000-0000-000000000000',
        '20000000-0000-4000-8000-000000000002',
        'authenticated',
        'authenticated',
        'pilot-b@thrustline.invalid',
        '',
        '2026-07-28 00:00:00+00',
        '{"provider":"email","providers":["email"]}',
        '{}',
        '2026-07-28 00:00:00+00',
        '2026-07-28 00:00:00+00',
        '',
        '',
        '',
        '',
        false
    );

insert into public.companies (id, owner_id, name, created_at, updated_at)
values
    (
        'a0000000-0000-4000-8000-000000000001',
        '10000000-0000-4000-8000-000000000001',
        'Synthetic Alpha Air',
        '2026-07-28 00:00:00+00',
        '2026-07-28 00:00:00+00'
    ),
    (
        'b0000000-0000-4000-8000-000000000002',
        '20000000-0000-4000-8000-000000000002',
        'Synthetic Bravo Air',
        '2026-07-28 00:00:00+00',
        '2026-07-28 00:00:00+00'
    );

insert into public.aircraft_purchase_offers (
    id,
    aircraft_type_code,
    serial_number,
    display_name,
    price_minor,
    currency_code
)
values
    (
        'e1000000-0000-4000-8000-000000000001',
        'C172',
        'SYN-C172-0001',
        'Synthetic Cessna 172',
        10000000,
        'EUR'
    ),
    (
        'e2000000-0000-4000-8000-000000000002',
        'TBM9',
        'SYN-TBM9-0002',
        'Synthetic TBM 930',
        50000000,
        'EUR'
    );
