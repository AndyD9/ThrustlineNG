alter table private.financial_ledger_entries
    drop constraint financial_ledger_entries_one_opening,
    drop constraint financial_ledger_entries_first_sequence,
    drop constraint financial_ledger_entries_opening_type;

alter table private.financial_ledger_entries
    add constraint financial_ledger_entries_positive_sequence
        check (sequence_number > 0),
    add constraint financial_ledger_entries_known_type
        check (entry_type in ('opening_balance', 'aircraft_purchase')),
    add constraint financial_ledger_entries_purchase_negative
        check (entry_type <> 'aircraft_purchase' or amount_minor < 0);

create unique index financial_ledger_entries_one_opening
    on private.financial_ledger_entries (subject_id)
    where entry_type = 'opening_balance';

create table public.aircraft_purchase_offers (
    id uuid primary key,
    aircraft_type_code text not null,
    serial_number text not null unique,
    display_name text not null,
    price_minor bigint not null,
    currency_code text not null,
    seller_kind text not null default 'system',
    status text not null default 'available',
    created_at timestamptz not null default clock_timestamp(),
    sold_at timestamptz,
    schema_version integer not null default 1,
    constraint aircraft_purchase_offers_type_code check (
        aircraft_type_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'
    ),
    constraint aircraft_purchase_offers_serial check (
        serial_number ~ '^[A-Z0-9][A-Z0-9-]{2,31}$'
    ),
    constraint aircraft_purchase_offers_display_name check (
        display_name = btrim(display_name)
        and char_length(display_name) between 2 and 80
    ),
    constraint aircraft_purchase_offers_price check (
        price_minor between 1 and 1000000000000000
    ),
    constraint aircraft_purchase_offers_currency check (
        currency_code = 'EUR'
    ),
    constraint aircraft_purchase_offers_seller check (
        seller_kind = 'system'
    ),
    constraint aircraft_purchase_offers_status check (
        status in ('available', 'sold')
    ),
    constraint aircraft_purchase_offers_lifecycle check (
        (status = 'available' and sold_at is null)
        or
        (status = 'sold' and sold_at is not null)
    ),
    constraint aircraft_purchase_offers_schema_version check (schema_version = 1)
);

create table public.company_aircraft (
    id uuid primary key default gen_random_uuid(),
    company_id uuid not null references public.companies (id) on delete cascade,
    offer_id uuid not null unique references public.aircraft_purchase_offers (id) on delete restrict,
    aircraft_type_code text not null,
    serial_number text not null unique,
    display_name text not null,
    acquisition_kind text not null default 'purchase',
    acquired_at timestamptz not null default clock_timestamp(),
    schema_version integer not null default 1,
    constraint company_aircraft_type_code check (
        aircraft_type_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'
    ),
    constraint company_aircraft_serial check (
        serial_number ~ '^[A-Z0-9][A-Z0-9-]{2,31}$'
    ),
    constraint company_aircraft_display_name check (
        display_name = btrim(display_name)
        and char_length(display_name) between 2 and 80
    ),
    constraint company_aircraft_purchase_only check (acquisition_kind = 'purchase'),
    constraint company_aircraft_schema_version check (schema_version = 1)
);

create table private.aircraft_purchase_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    idempotency_key uuid not null,
    company_id uuid not null references public.companies (id) on delete cascade,
    offer_id uuid not null references public.aircraft_purchase_offers (id) on delete restrict,
    payload_sha256 text not null,
    aircraft_id uuid not null references public.company_aircraft (id) on delete cascade,
    ledger_entry_id uuid not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, idempotency_key),
    constraint aircraft_purchase_commands_payload_hash check (
        payload_sha256 ~ '^[0-9a-f]{64}$'
    ),
    constraint aircraft_purchase_commands_aircraft unique (aircraft_id),
    constraint aircraft_purchase_commands_ledger unique (ledger_entry_id)
);

alter table public.aircraft_purchase_offers enable row level security;
alter table public.aircraft_purchase_offers force row level security;
alter table public.company_aircraft enable row level security;
alter table public.company_aircraft force row level security;
alter table private.aircraft_purchase_commands enable row level security;
alter table private.aircraft_purchase_commands force row level security;

revoke all on table public.aircraft_purchase_offers from public;
revoke all on table public.aircraft_purchase_offers from anon;
revoke all on table public.aircraft_purchase_offers from authenticated;
revoke all on table public.aircraft_purchase_offers from service_role;
grant select on table public.aircraft_purchase_offers to authenticated;

revoke all on table public.company_aircraft from public;
revoke all on table public.company_aircraft from anon;
revoke all on table public.company_aircraft from authenticated;
revoke all on table public.company_aircraft from service_role;
grant select on table public.company_aircraft to authenticated;

revoke all on table private.aircraft_purchase_commands from public;
revoke all on table private.aircraft_purchase_commands from anon;
revoke all on table private.aircraft_purchase_commands from authenticated;
revoke all on table private.aircraft_purchase_commands from service_role;

create policy aircraft_purchase_offers_select_available
on public.aircraft_purchase_offers
for select
to authenticated
using (status = 'available');

create policy company_aircraft_select_own
on public.company_aircraft
for select
to authenticated
using (
    exists (
        select 1
        from public.companies as companies
        where companies.id = company_aircraft.company_id
          and companies.owner_id = (select auth.uid())
    )
);

comment on table public.aircraft_purchase_offers is
    'Server-controlled, single-unit synthetic purchase offers; authenticated clients can only read available offers.';
comment on table public.company_aircraft is
    'Aircraft ownership created atomically by the authoritative purchase command.';
comment on table private.aircraft_purchase_commands is
    'Private idempotency registry binding an owner and offer to one aircraft and one immutable debit.';

create function public.purchase_aircraft(
    owner_id uuid,
    idempotency_key uuid,
    offer_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    company public.companies%rowtype;
    subject private.financial_ledger_subjects%rowtype;
    offer public.aircraft_purchase_offers%rowtype;
    existing_command private.aircraft_purchase_commands%rowtype;
    aircraft public.company_aircraft%rowtype;
    ledger_entry private.financial_ledger_entries%rowtype;
    payload_hash text;
    ledger_balance bigint;
    ledger_currency text;
    ledger_currency_count bigint;
    next_sequence bigint;
begin
    if owner_id is null or idempotency_key is null or offer_id is null then
        raise invalid_parameter_value using
            message = 'Owner, idempotency key and offer are required.';
    end if;

    payload_hash := encode(
        extensions.digest(
            convert_to(
                jsonb_build_object('offerId', offer_id)::text,
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    );

    select companies.*
    into company
    from public.companies as companies
    where companies.owner_id = purchase_aircraft.owner_id
    for update;

    if not found or not private.account_is_active(purchase_aircraft.owner_id) then
        raise object_not_in_prerequisite_state using
            message = 'Aircraft purchase is unavailable.';
    end if;

    select subjects.*
    into strict subject
    from private.financial_ledger_subjects as subjects
    where subjects.company_id = company.id
      and subjects.anonymized_at is null
    for update;

    select commands.*
    into existing_command
    from private.aircraft_purchase_commands as commands
    where commands.owner_id = purchase_aircraft.owner_id
      and commands.idempotency_key = purchase_aircraft.idempotency_key;

    if found then
        if existing_command.offer_id <> purchase_aircraft.offer_id
            or existing_command.payload_sha256 <> payload_hash
        then
            raise invalid_parameter_value using
                message = 'Idempotency key was already used with a different payload.';
        end if;

        return jsonb_build_object(
            'aircraftId', existing_command.aircraft_id,
            'ledgerEntryId', existing_command.ledger_entry_id,
            'offerId', existing_command.offer_id,
            'schemaVersion', 1,
            'state', 'owned'
        );
    end if;

    select offers.*
    into offer
    from public.aircraft_purchase_offers as offers
    where offers.id = purchase_aircraft.offer_id
    for update;

    if not found or offer.status <> 'available' then
        raise object_not_in_prerequisite_state using
            message = 'Aircraft offer is unavailable.';
    end if;

    select
        coalesce(sum(entries.amount_minor), 0),
        min(entries.currency_code),
        count(distinct entries.currency_code)
    into ledger_balance, ledger_currency, ledger_currency_count
    from private.financial_ledger_entries as entries
    where entries.subject_id = subject.subject_id;

    if ledger_currency_count <> 1 or ledger_currency <> offer.currency_code then
        raise object_not_in_prerequisite_state using
            message = 'Aircraft offer currency does not match the company ledger.';
    end if;

    if ledger_balance < offer.price_minor then
        raise check_violation using
            message = 'Company balance is insufficient for this aircraft.';
    end if;

    select coalesce(max(entries.sequence_number), 0) + 1
    into next_sequence
    from private.financial_ledger_entries as entries
    where entries.subject_id = subject.subject_id;

    insert into public.company_aircraft (
        company_id,
        offer_id,
        aircraft_type_code,
        serial_number,
        display_name
    )
    values (
        company.id,
        offer.id,
        offer.aircraft_type_code,
        offer.serial_number,
        offer.display_name
    )
    returning *
    into aircraft;

    insert into private.financial_ledger_entries (
        subject_id,
        sequence_number,
        idempotency_key,
        entry_type,
        amount_minor,
        currency_code
    )
    values (
        subject.subject_id,
        next_sequence,
        purchase_aircraft.idempotency_key,
        'aircraft_purchase',
        -offer.price_minor,
        offer.currency_code
    )
    returning *
    into ledger_entry;

    update public.aircraft_purchase_offers as offers
    set status = 'sold',
        sold_at = ledger_entry.recorded_at
    where offers.id = offer.id;

    insert into private.aircraft_purchase_commands (
        owner_id,
        idempotency_key,
        company_id,
        offer_id,
        payload_sha256,
        aircraft_id,
        ledger_entry_id
    )
    values (
        purchase_aircraft.owner_id,
        purchase_aircraft.idempotency_key,
        company.id,
        offer.id,
        payload_hash,
        aircraft.id,
        ledger_entry.id
    );

    return jsonb_build_object(
        'aircraftId', aircraft.id,
        'ledgerEntryId', ledger_entry.id,
        'offerId', offer.id,
        'schemaVersion', 1,
        'state', 'owned'
    );
end;
$$;

revoke all on function public.purchase_aircraft(uuid, uuid, uuid) from public;
revoke all on function public.purchase_aircraft(uuid, uuid, uuid) from anon;
revoke all on function public.purchase_aircraft(uuid, uuid, uuid) from authenticated;
grant execute on function public.purchase_aircraft(uuid, uuid, uuid) to service_role;

create function public.get_company_aircraft()
returns table (
    aircraft_id uuid,
    offer_id uuid,
    aircraft_type_code text,
    serial_number text,
    display_name text,
    acquisition_kind text,
    acquired_at timestamptz,
    schema_version integer
)
language sql
stable
security definer
set search_path = ''
as $$
    select
        aircraft.id,
        aircraft.offer_id,
        aircraft.aircraft_type_code,
        aircraft.serial_number,
        aircraft.display_name,
        aircraft.acquisition_kind,
        aircraft.acquired_at,
        aircraft.schema_version
    from public.company_aircraft as aircraft
    join public.companies as companies
      on companies.id = aircraft.company_id
    where companies.owner_id = (select auth.uid())
    order by aircraft.acquired_at, aircraft.id;
$$;

revoke all on function public.get_company_aircraft() from public;
revoke all on function public.get_company_aircraft() from anon;
grant execute on function public.get_company_aircraft() to authenticated;
