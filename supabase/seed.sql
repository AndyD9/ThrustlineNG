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

-- Synthetic lease offers carrying the terms Andy approved on 4 August 2026:
-- 30 days, one rent every 24 hours paid in advance, a non-refundable set-up fee
-- of ten rents, 72 hours of grace with the aircraft suspended, and voluntary
-- termination penalised by two rents capped at the rent still due. The rent is
-- authored per offer inside the band the migration enforces.
insert into public.aircraft_purchase_offers (
    id, aircraft_type_code, serial_number, display_name, price_minor,
    currency_code, offer_kind, terms_version, duration_days, cadence_hours,
    rent_minor, initial_payment_minor, grace_hours, voluntary_termination,
    termination_penalty_minor, usable_during_grace
)
values
    (
        'ea000000-0000-4000-8000-000000000003', 'C172', 'SYN-C172-LEASE-0003',
        'Synthetic Cessna 172 Lease', 10000000, 'EUR', 'lease', 1, 30, 24,
        25000, 250000, 72, true, 50000, false
    ),
    (
        'eb000000-0000-4000-8000-000000000004', 'TBM9', 'SYN-TBM9-LEASE-0004',
        'Synthetic TBM 930 Lease', 50000000, 'EUR', 'lease', 1, 30, 24,
        90000, 900000, 72, true, 180000, false
    );

-- Bounded aerodrome reference, projected verbatim from eng/airports.json, which
-- stays the canonical source. The load is idempotent so a repeated reset cannot
-- duplicate or drift from the source. No identity and no personal data.
insert into public.airports (icao_code, name, latitude, longitude, popularity_tier)
values
    ('CYYZ', 'Toronto Pearson', 43.6777, -79.6248, 'major'),
    ('EBBR', 'Brussels', 50.9014, 4.4844, 'major'),
    ('EDDF', 'Frankfurt am Main', 50.0379, 8.5622, 'hub'),
    ('EDDH', 'Hamburg', 53.6304, 9.9882, 'standard'),
    ('EDDK', 'Cologne Bonn', 50.8659, 7.1427, 'standard'),
    ('EDDL', 'Dusseldorf', 51.2895, 6.7668, 'standard'),
    ('EDDM', 'Munich', 48.3537, 11.7751, 'major'),
    ('EDDS', 'Stuttgart', 48.6899, 9.2220, 'standard'),
    ('EGBB', 'Birmingham', 52.4539, -1.7480, 'standard'),
    ('EGCC', 'Manchester', 53.3537, -2.2750, 'major'),
    ('EGGD', 'Bristol', 51.3827, -2.7191, 'standard'),
    ('EGKK', 'London Gatwick', 51.1537, -0.1821, 'major'),
    ('EGLL', 'London Heathrow', 51.4700, -0.4543, 'hub'),
    ('EGPF', 'Glasgow', 55.8719, -4.4331, 'standard'),
    ('EGPH', 'Edinburgh', 55.9500, -3.3725, 'standard'),
    ('EGSS', 'London Stansted', 51.8850, 0.2350, 'standard'),
    ('EHAM', 'Amsterdam Schiphol', 52.3105, 4.7683, 'hub'),
    ('EHEH', 'Eindhoven', 51.4501, 5.3745, 'standard'),
    ('EIDW', 'Dublin', 53.4213, -6.2701, 'major'),
    ('EKCH', 'Copenhagen Kastrup', 55.6180, 12.6508, 'major'),
    ('ELLX', 'Luxembourg Findel', 49.6266, 6.2115, 'standard'),
    ('ENGM', 'Oslo Gardermoen', 60.1939, 11.1004, 'major'),
    ('EPWA', 'Warsaw Chopin', 52.1657, 20.9671, 'major'),
    ('ESSA', 'Stockholm Arlanda', 59.6519, 17.9186, 'major'),
    ('FAOR', 'Johannesburg OR Tambo', -26.1392, 28.2460, 'major'),
    ('HECA', 'Cairo', 30.1219, 31.4056, 'major'),
    ('KATL', 'Atlanta Hartsfield Jackson', 33.6407, -84.4277, 'hub'),
    ('KBOS', 'Boston Logan', 42.3656, -71.0096, 'major'),
    ('KDEN', 'Denver', 39.8561, -104.6737, 'major'),
    ('KJFK', 'New York John F Kennedy', 40.6413, -73.7781, 'hub'),
    ('KLAX', 'Los Angeles', 33.9416, -118.4085, 'hub'),
    ('KMIA', 'Miami', 25.7959, -80.2871, 'major'),
    ('KORD', 'Chicago O''Hare', 41.9742, -87.9073, 'hub'),
    ('KSEA', 'Seattle Tacoma', 47.4502, -122.3088, 'major'),
    ('KSFO', 'San Francisco', 37.6213, -122.3790, 'major'),
    ('LEAL', 'Alicante Elche', 38.2822, -0.5582, 'standard'),
    ('LEBL', 'Barcelona El Prat', 41.2971, 2.0785, 'major'),
    ('LEMD', 'Madrid Barajas', 40.4719, -3.5626, 'hub'),
    ('LEMG', 'Malaga Costa del Sol', 36.6749, -4.4991, 'standard'),
    ('LEPA', 'Palma de Mallorca', 39.5517, 2.7388, 'standard'),
    ('LEVC', 'Valencia', 39.4893, -0.4816, 'standard'),
    ('LEZL', 'Seville', 37.4180, -5.8931, 'standard'),
    ('LFAT', 'Le Touquet Paris Plage', 50.5174, 1.6272, 'regional'),
    ('LFBD', 'Bordeaux Merignac', 44.8283, -0.7156, 'standard'),
    ('LFBE', 'Bergerac Dordogne Perigord', 44.8253, 0.5186, 'regional'),
    ('LFBO', 'Toulouse Blagnac', 43.6291, 1.3638, 'standard'),
    ('LFBP', 'Pau Pyrenees', 43.3800, -0.4186, 'regional'),
    ('LFBT', 'Tarbes Lourdes Pyrenees', 43.1787, -0.0064, 'regional'),
    ('LFBZ', 'Biarritz Pays Basque', 43.4684, -1.5233, 'regional'),
    ('LFCR', 'Rodez Aveyron', 44.4079, 2.4826, 'regional'),
    ('LFKB', 'Bastia Poretta', 42.5527, 9.4837, 'regional'),
    ('LFKJ', 'Ajaccio Napoleon Bonaparte', 41.9236, 8.8029, 'regional'),
    ('LFLB', 'Chambery Savoie Mont Blanc', 45.6381, 5.8800, 'regional'),
    ('LFLC', 'Clermont Ferrand Auvergne', 45.7867, 3.1692, 'standard'),
    ('LFLL', 'Lyon Saint Exupery', 45.7256, 5.0811, 'standard'),
    ('LFLP', 'Annecy Mont Blanc', 45.9308, 6.1064, 'regional'),
    ('LFLS', 'Grenoble Alpes Isere', 45.3629, 5.3294, 'regional'),
    ('LFMK', 'Carcassonne Salvaza', 43.2160, 2.3063, 'regional'),
    ('LFML', 'Marseille Provence', 43.4393, 5.2214, 'standard'),
    ('LFMN', 'Nice Cote d''Azur', 43.6653, 7.2158, 'major'),
    ('LFMP', 'Perpignan Rivesaltes', 42.7404, 2.8707, 'regional'),
    ('LFMT', 'Montpellier Mediterranee', 43.5762, 3.9630, 'standard'),
    ('LFMU', 'Beziers Cap d''Agde', 43.3235, 3.3540, 'regional'),
    ('LFOB', 'Beauvais Tille', 49.4544, 2.1128, 'regional'),
    ('LFOH', 'Le Havre Octeville', 49.5340, 0.0880, 'regional'),
    ('LFPG', 'Paris Charles de Gaulle', 49.0097, 2.5479, 'hub'),
    ('LFPO', 'Paris Orly', 48.7233, 2.3794, 'major'),
    ('LFQQ', 'Lille Lesquin', 50.5619, 3.0894, 'standard'),
    ('LFRB', 'Brest Bretagne', 48.4479, -4.4185, 'standard'),
    ('LFRD', 'Dinard Pleurtuit Saint Malo', 48.5877, -2.0800, 'regional'),
    ('LFRH', 'Lorient Bretagne Sud', 47.7606, -3.4400, 'regional'),
    ('LFRK', 'Caen Carpiquet', 49.1733, -0.4500, 'regional'),
    ('LFRQ', 'Quimper Bretagne', 47.9750, -4.1678, 'regional'),
    ('LFRS', 'Nantes Atlantique', 47.1532, -1.6107, 'standard'),
    ('LFSB', 'Basel Mulhouse Freiburg', 47.5896, 7.5299, 'standard'),
    ('LFST', 'Strasbourg Entzheim', 48.5383, 7.6282, 'standard'),
    ('LHBP', 'Budapest Ferenc Liszt', 47.4369, 19.2556, 'major'),
    ('LIMC', 'Milan Malpensa', 45.6306, 8.7281, 'standard'),
    ('LIML', 'Milan Linate', 45.4451, 9.2767, 'standard'),
    ('LIPZ', 'Venice Marco Polo', 45.5053, 12.3519, 'standard'),
    ('LIRF', 'Rome Fiumicino', 41.8003, 12.2389, 'major'),
    ('LIRN', 'Naples Capodichino', 40.8860, 14.2908, 'standard'),
    ('LKPR', 'Prague Vaclav Havel', 50.1008, 14.2600, 'major'),
    ('LOWW', 'Vienna Schwechat', 48.1103, 16.5697, 'major'),
    ('LPPT', 'Lisbon Humberto Delgado', 38.7756, -9.1354, 'major'),
    ('LSGG', 'Geneva Cointrin', 46.2381, 6.1090, 'standard'),
    ('LSZH', 'Zurich', 47.4647, 8.5492, 'major'),
    ('LTFM', 'Istanbul', 41.2753, 28.7519, 'hub'),
    ('MMMX', 'Mexico City Benito Juarez', 19.4363, -99.0721, 'major'),
    ('NZAA', 'Auckland', -37.0082, 174.7850, 'major'),
    ('OMDB', 'Dubai', 25.2532, 55.3657, 'hub'),
    ('OTHH', 'Doha Hamad', 25.2731, 51.6081, 'major'),
    ('RJTT', 'Tokyo Haneda', 35.5494, 139.7798, 'hub'),
    ('RKSI', 'Seoul Incheon', 37.4602, 126.4407, 'major'),
    ('RPLL', 'Manila Ninoy Aquino', 14.5086, 121.0198, 'major'),
    ('SBGR', 'Sao Paulo Guarulhos', -23.4356, -46.4731, 'major'),
    ('VHHH', 'Hong Kong', 22.3080, 113.9185, 'hub'),
    ('VIDP', 'Delhi Indira Gandhi', 28.5562, 77.1000, 'major'),
    ('VTBS', 'Bangkok Suvarnabhumi', 13.6900, 100.7501, 'major'),
    ('WMKK', 'Kuala Lumpur', 2.7456, 101.7099, 'major'),
    ('WSSS', 'Singapore Changi', 1.3644, 103.9915, 'hub'),
    ('YSSY', 'Sydney Kingsford Smith', -33.9399, 151.1753, 'major'),
    ('ZBAA', 'Beijing Capital', 40.0801, 116.5846, 'hub')
on conflict (icao_code) do update
set name = excluded.name,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    popularity_tier = excluded.popularity_tier;
