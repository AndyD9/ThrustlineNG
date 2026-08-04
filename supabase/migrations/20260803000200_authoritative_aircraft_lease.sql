alter table private.financial_ledger_entries
    drop constraint financial_ledger_entries_known_type,
    drop constraint financial_ledger_entries_purchase_negative;

alter table private.financial_ledger_entries
    add constraint financial_ledger_entries_known_type
        check (entry_type in ('opening_balance', 'aircraft_purchase', 'aircraft_lease_rent')),
    add constraint financial_ledger_entries_acquisition_negative
        check (
            entry_type not in ('aircraft_purchase', 'aircraft_lease_rent')
            or amount_minor < 0
        );

alter table public.aircraft_purchase_offers
    drop constraint aircraft_purchase_offers_status,
    drop constraint aircraft_purchase_offers_lifecycle,
    add column offer_kind text not null default 'purchase',
    add column terms_version integer,
    add column duration_days integer,
    add column cadence_hours integer,
    add column rent_minor bigint,
    add column initial_payment_minor bigint,
    add column grace_hours integer,
    add column voluntary_termination boolean,
    add column termination_penalty_minor bigint,
    add column usable_during_grace boolean;

alter table public.aircraft_purchase_offers
    add constraint aircraft_offers_kind check (offer_kind in ('purchase', 'lease')),
    add constraint aircraft_offers_status check (status in ('available', 'sold', 'leased')),
    add constraint aircraft_offers_lifecycle check (
        (status = 'available' and sold_at is null)
        or (status = 'sold' and offer_kind = 'purchase' and sold_at is not null)
        or (status = 'leased' and offer_kind = 'lease' and sold_at is not null)
    ),
    add constraint aircraft_offers_terms check (
        (
            offer_kind = 'purchase'
            and terms_version is null
            and duration_days is null
            and cadence_hours is null
            and rent_minor is null
            and initial_payment_minor is null
            and grace_hours is null
            and voluntary_termination is null
            and termination_penalty_minor is null
            and usable_during_grace is null
        )
        or
        (
            offer_kind = 'lease'
            and terms_version = 1
            and duration_days = 30
            and cadence_hours = 24
            and rent_minor = (price_minor + 199) / 200
            and initial_payment_minor = rent_minor
            and grace_hours = 48
            and voluntary_termination is true
            and termination_penalty_minor = 0
            and usable_during_grace is true
        )
    );

alter table public.company_aircraft
    drop constraint company_aircraft_purchase_only,
    add column is_usable boolean not null default true,
    add constraint company_aircraft_acquisition_kind
        check (acquisition_kind in ('purchase', 'lease'));

create function private.validate_aircraft_acquisition_kind()
returns trigger language plpgsql set search_path = '' as $$
declare
    expected_kind text;
begin
    select offer_kind into expected_kind
    from public.aircraft_purchase_offers
    where id = new.offer_id;
    if expected_kind is null or expected_kind <> new.acquisition_kind then
        raise object_not_in_prerequisite_state using
            message = 'Aircraft acquisition does not match the server offer.';
    end if;
    return new;
end;
$$;

revoke all on function private.validate_aircraft_acquisition_kind() from public, anon, authenticated;

create trigger company_aircraft_validate_acquisition_kind
before insert on public.company_aircraft
for each row execute function private.validate_aircraft_acquisition_kind();

create table public.aircraft_lease_contracts (
    id uuid primary key default gen_random_uuid(),
    company_id uuid references public.companies (id) on delete set null,
    offer_id uuid not null unique references public.aircraft_purchase_offers (id) on delete restrict,
    aircraft_id uuid unique references public.company_aircraft (id) on delete set null,
    terms_version integer not null,
    currency_code text not null,
    reference_price_minor bigint not null,
    rent_minor bigint not null,
    duration_days integer not null,
    cadence_hours integer not null,
    grace_hours integer not null,
    initial_payment_minor bigint not null,
    voluntary_termination boolean not null,
    termination_penalty_minor bigint not null,
    usable_during_grace boolean not null,
    state text not null default 'active',
    activated_at timestamptz not null,
    ends_at timestamptz not null,
    terminated_at timestamptz,
    created_at timestamptz not null default clock_timestamp(),
    schema_version integer not null default 1,
    constraint aircraft_lease_contract_terms check (
        terms_version = 1
        and currency_code = 'EUR'
        and reference_price_minor > 0
        and rent_minor = (reference_price_minor + 199) / 200
        and duration_days = 30
        and cadence_hours = 24
        and grace_hours = 48
        and initial_payment_minor = rent_minor
        and voluntary_termination is true
        and termination_penalty_minor = 0
        and usable_during_grace is true
    ),
    constraint aircraft_lease_contract_state
        check (state in ('active', 'grace', 'defaulted', 'expired', 'terminated')),
    constraint aircraft_lease_contract_dates check (
        ends_at = activated_at + interval '30 days'
        and (
            (state in ('active', 'grace') and terminated_at is null)
            or (state in ('defaulted', 'expired', 'terminated') and terminated_at is not null)
        )
    ),
    constraint aircraft_lease_contract_schema_version check (schema_version = 1)
);

create table public.aircraft_lease_installments (
    id uuid primary key default gen_random_uuid(),
    contract_id uuid not null references public.aircraft_lease_contracts (id) on delete restrict,
    installment_number integer not null,
    due_at timestamptz not null,
    amount_minor bigint not null,
    currency_code text not null,
    state text not null,
    grace_until timestamptz,
    paid_at timestamptz,
    ledger_entry_id uuid unique,
    created_at timestamptz not null default clock_timestamp(),
    schema_version integer not null default 1,
    constraint aircraft_lease_installment_identity unique (contract_id, installment_number),
    constraint aircraft_lease_installment_number check (installment_number between 1 and 30),
    constraint aircraft_lease_installment_amount check (amount_minor > 0),
    constraint aircraft_lease_installment_currency check (currency_code = 'EUR'),
    constraint aircraft_lease_installment_state check (state in ('paid', 'grace', 'defaulted')),
    constraint aircraft_lease_installment_lifecycle check (
        (state = 'paid' and paid_at is not null and ledger_entry_id is not null)
        or (state = 'grace' and paid_at is null and ledger_entry_id is null and grace_until is not null)
        or (state = 'defaulted' and paid_at is null and ledger_entry_id is null and grace_until is not null)
    ),
    constraint aircraft_lease_installment_schema_version check (schema_version = 1)
);

create table private.aircraft_lease_events (
    id uuid primary key default gen_random_uuid(),
    contract_id uuid not null references public.aircraft_lease_contracts (id) on delete restrict,
    event_type text not null,
    installment_number integer,
    effective_at timestamptz not null,
    idempotency_key uuid not null,
    created_at timestamptz not null default clock_timestamp(),
    constraint aircraft_lease_event_type check (
        event_type in ('activated', 'rent_paid', 'grace_started', 'defaulted', 'expired', 'terminated')
    ),
    constraint aircraft_lease_event_identity unique (contract_id, idempotency_key, event_type, installment_number)
);

create table private.aircraft_lease_creation_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    idempotency_key uuid not null,
    company_id uuid not null references public.companies (id) on delete cascade,
    offer_id uuid not null references public.aircraft_purchase_offers (id) on delete restrict,
    payload_sha256 text not null,
    contract_id uuid not null unique references public.aircraft_lease_contracts (id) on delete restrict,
    aircraft_id uuid not null unique references public.company_aircraft (id) on delete cascade,
    ledger_entry_id uuid not null unique,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, idempotency_key),
    constraint aircraft_lease_creation_payload_hash check (payload_sha256 ~ '^[0-9a-f]{64}$')
);

create table private.aircraft_lease_temporal_commands (
    contract_id uuid not null references public.aircraft_lease_contracts (id) on delete restrict,
    idempotency_key uuid not null,
    effective_at timestamptz not null,
    result jsonb not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (contract_id, idempotency_key)
);

create table private.aircraft_lease_termination_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    idempotency_key uuid not null,
    contract_id uuid not null references public.aircraft_lease_contracts (id) on delete restrict,
    result jsonb not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, idempotency_key)
);

alter table public.aircraft_lease_contracts enable row level security;
alter table public.aircraft_lease_contracts force row level security;
alter table public.aircraft_lease_installments enable row level security;
alter table public.aircraft_lease_installments force row level security;
alter table private.aircraft_lease_events enable row level security;
alter table private.aircraft_lease_events force row level security;
alter table private.aircraft_lease_creation_commands enable row level security;
alter table private.aircraft_lease_creation_commands force row level security;
alter table private.aircraft_lease_temporal_commands enable row level security;
alter table private.aircraft_lease_temporal_commands force row level security;
alter table private.aircraft_lease_termination_commands enable row level security;
alter table private.aircraft_lease_termination_commands force row level security;

revoke all on table public.aircraft_lease_contracts from public, anon, authenticated, service_role;
revoke all on table public.aircraft_lease_installments from public, anon, authenticated, service_role;
grant select on table public.aircraft_lease_contracts to authenticated;
grant select on table public.aircraft_lease_installments to authenticated;
revoke all on table private.aircraft_lease_events from public, anon, authenticated, service_role;
revoke all on table private.aircraft_lease_creation_commands from public, anon, authenticated, service_role;
revoke all on table private.aircraft_lease_temporal_commands from public, anon, authenticated, service_role;
revoke all on table private.aircraft_lease_termination_commands from public, anon, authenticated, service_role;

create policy aircraft_lease_contracts_select_own
on public.aircraft_lease_contracts for select to authenticated
using (
    exists (
        select 1 from public.companies
        where companies.id = aircraft_lease_contracts.company_id
          and companies.owner_id = (select auth.uid())
    )
);

create policy aircraft_lease_installments_select_own
on public.aircraft_lease_installments for select to authenticated
using (
    exists (
        select 1
        from public.aircraft_lease_contracts
        join public.companies on companies.id = aircraft_lease_contracts.company_id
        where aircraft_lease_contracts.id = aircraft_lease_installments.contract_id
          and companies.owner_id = (select auth.uid())
    )
);

create function private.reject_aircraft_lease_event_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin
    raise object_not_in_prerequisite_state using message = 'Aircraft lease events are append-only.';
end;
$$;

revoke all on function private.reject_aircraft_lease_event_mutation() from public, anon, authenticated;

create trigger aircraft_lease_events_reject_update_delete
before update or delete on private.aircraft_lease_events
for each row execute function private.reject_aircraft_lease_event_mutation();

create trigger aircraft_lease_events_reject_truncate
before truncate on private.aircraft_lease_events
for each statement execute function private.reject_aircraft_lease_event_mutation();

create function private.terminate_aircraft_leases_before_company_delete()
returns trigger language plpgsql set search_path = '' as $$
declare
    contract_record record;
    effective timestamptz := transaction_timestamp();
begin
    for contract_record in
        update public.aircraft_lease_contracts
        set state = 'terminated', terminated_at = effective
        where company_id = old.id and state in ('active', 'grace')
        returning id, aircraft_id
    loop
        update public.company_aircraft set is_usable = false where id = contract_record.aircraft_id;
        insert into private.aircraft_lease_events (
            contract_id, event_type, effective_at, idempotency_key
        ) values (
            contract_record.id, 'terminated', effective, gen_random_uuid()
        );
    end loop;
    return old;
end;
$$;

revoke all on function private.terminate_aircraft_leases_before_company_delete() from public, anon, authenticated;

create trigger companies_terminate_aircraft_leases
before delete on public.companies
for each row execute function private.terminate_aircraft_leases_before_company_delete();

create function public.lease_aircraft(owner_id uuid, idempotency_key uuid, offer_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
    company public.companies%rowtype;
    subject private.financial_ledger_subjects%rowtype;
    offer public.aircraft_purchase_offers%rowtype;
    existing private.aircraft_lease_creation_commands%rowtype;
    aircraft public.company_aircraft%rowtype;
    contract public.aircraft_lease_contracts%rowtype;
    installment public.aircraft_lease_installments%rowtype;
    installment_id uuid := gen_random_uuid();
    ledger_entry private.financial_ledger_entries%rowtype;
    payload_hash text;
    ledger_balance bigint;
    ledger_currency text;
    ledger_currency_count bigint;
    next_sequence bigint;
    activated timestamptz := transaction_timestamp();
begin
    if owner_id is null or idempotency_key is null or offer_id is null then
        raise invalid_parameter_value using message = 'Owner, idempotency key and offer are required.';
    end if;

    payload_hash := encode(extensions.digest(convert_to(jsonb_build_object('offerId', offer_id)::text, 'UTF8'), 'sha256'), 'hex');

    select * into company from public.companies
    where companies.owner_id = lease_aircraft.owner_id for update;
    if not found or not private.account_is_active(lease_aircraft.owner_id) then
        raise object_not_in_prerequisite_state using message = 'Aircraft lease is unavailable.';
    end if;

    select * into strict subject from private.financial_ledger_subjects
    where company_id = company.id and anonymized_at is null for update;

    select * into existing from private.aircraft_lease_creation_commands
    where aircraft_lease_creation_commands.owner_id = lease_aircraft.owner_id
      and aircraft_lease_creation_commands.idempotency_key = lease_aircraft.idempotency_key;
    if found then
        if existing.offer_id <> lease_aircraft.offer_id or existing.payload_sha256 <> payload_hash then
            raise invalid_parameter_value using message = 'Idempotency key was already used with a different payload.';
        end if;
        return jsonb_build_object('aircraftId', existing.aircraft_id, 'contractId', existing.contract_id,
            'ledgerEntryId', existing.ledger_entry_id, 'offerId', existing.offer_id,
            'schemaVersion', 1, 'state', 'active');
    end if;

    select * into offer from public.aircraft_purchase_offers
    where id = lease_aircraft.offer_id for update;
    if not found or offer.status <> 'available' or offer.offer_kind <> 'lease' then
        raise object_not_in_prerequisite_state using message = 'Aircraft lease offer is unavailable.';
    end if;

    select coalesce(sum(amount_minor), 0), min(currency_code), count(distinct currency_code)
    into ledger_balance, ledger_currency, ledger_currency_count
    from private.financial_ledger_entries where subject_id = subject.subject_id;
    if ledger_currency_count <> 1 or ledger_currency <> offer.currency_code then
        raise object_not_in_prerequisite_state using message = 'Aircraft offer currency does not match the company ledger.';
    end if;
    if ledger_balance < offer.initial_payment_minor then
        raise check_violation using message = 'Company balance is insufficient for this aircraft lease.';
    end if;
    select coalesce(max(sequence_number), 0) + 1 into next_sequence
    from private.financial_ledger_entries where subject_id = subject.subject_id;

    insert into public.company_aircraft (
        company_id, offer_id, aircraft_type_code, serial_number, display_name, acquisition_kind, acquired_at, is_usable
    ) values (
        company.id, offer.id, offer.aircraft_type_code, offer.serial_number, offer.display_name, 'lease', activated, true
    ) returning * into aircraft;

    insert into public.aircraft_lease_contracts (
        company_id, offer_id, aircraft_id, terms_version, currency_code, reference_price_minor,
        rent_minor, duration_days, cadence_hours, grace_hours, initial_payment_minor,
        voluntary_termination, termination_penalty_minor, usable_during_grace,
        activated_at, ends_at
    ) values (
        company.id, offer.id, aircraft.id, offer.terms_version, offer.currency_code, offer.price_minor,
        offer.rent_minor, offer.duration_days, offer.cadence_hours, offer.grace_hours,
        offer.initial_payment_minor, offer.voluntary_termination, offer.termination_penalty_minor,
        offer.usable_during_grace, activated, activated + make_interval(days => offer.duration_days)
    ) returning * into contract;

    insert into private.financial_ledger_entries (
        subject_id, sequence_number, idempotency_key, entry_type, amount_minor, currency_code
    ) values (
        subject.subject_id, next_sequence, installment_id, 'aircraft_lease_rent', -contract.rent_minor, contract.currency_code
    ) returning * into ledger_entry;

    insert into public.aircraft_lease_installments (
        id, contract_id, installment_number, due_at, amount_minor, currency_code,
        state, paid_at, ledger_entry_id
    ) values (
        installment_id, contract.id, 1, activated, contract.rent_minor,
        contract.currency_code, 'paid', activated, ledger_entry.id
    ) returning * into installment;
    update public.aircraft_purchase_offers set status = 'leased', sold_at = activated where id = offer.id;

    insert into private.aircraft_lease_events (contract_id, event_type, installment_number, effective_at, idempotency_key)
    values
        (contract.id, 'activated', null, activated, idempotency_key),
        (contract.id, 'rent_paid', 1, activated, installment.id);

    insert into private.aircraft_lease_creation_commands (
        owner_id, idempotency_key, company_id, offer_id, payload_sha256, contract_id, aircraft_id, ledger_entry_id
    ) values (
        owner_id, idempotency_key, company.id, offer.id, payload_hash, contract.id, aircraft.id, ledger_entry.id
    );

    return jsonb_build_object('aircraftId', aircraft.id, 'contractId', contract.id,
        'ledgerEntryId', ledger_entry.id, 'offerId', offer.id, 'schemaVersion', 1, 'state', 'active');
end;
$$;

revoke all on function public.lease_aircraft(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.lease_aircraft(uuid, uuid, uuid) to service_role;

create function public.process_aircraft_lease(contract_id uuid, idempotency_key uuid, effective_at timestamptz default clock_timestamp())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
    contract public.aircraft_lease_contracts%rowtype;
    subject private.financial_ledger_subjects%rowtype;
    installment public.aircraft_lease_installments%rowtype;
    existing private.aircraft_lease_temporal_commands%rowtype;
    ledger_entry private.financial_ledger_entries%rowtype;
    result jsonb;
    ledger_balance bigint;
    next_sequence bigint;
    due timestamptz;
    installment_no integer;
    installment_id uuid;
    installment_exists boolean;
begin
    if contract_id is null or idempotency_key is null or effective_at is null then
        raise invalid_parameter_value using message = 'Contract, idempotency key and authoritative time are required.';
    end if;

    select * into contract from public.aircraft_lease_contracts
    where id = process_aircraft_lease.contract_id for update;
    if not found then
        raise object_not_in_prerequisite_state using message = 'Aircraft lease is unavailable.';
    end if;

    select * into existing from private.aircraft_lease_temporal_commands
    where aircraft_lease_temporal_commands.contract_id = process_aircraft_lease.contract_id
      and aircraft_lease_temporal_commands.idempotency_key = process_aircraft_lease.idempotency_key;
    if found then
        if existing.effective_at <> process_aircraft_lease.effective_at then
            raise invalid_parameter_value using message = 'Idempotency key was already used with a different authoritative time.';
        end if;
        return existing.result;
    end if;

    select * into strict subject from private.financial_ledger_subjects
    where company_id = contract.company_id and anonymized_at is null for update;

    if contract.state in ('defaulted', 'expired', 'terminated') then
        result := jsonb_build_object('contractId', contract.id, 'schemaVersion', 1, 'state', contract.state);
        insert into private.aircraft_lease_temporal_commands values (contract.id, idempotency_key, effective_at, result, clock_timestamp());
        return result;
    end if;

    for installment_no in 2..30 loop
        due := contract.activated_at + make_interval(hours => contract.cadence_hours * (installment_no - 1));
        exit when due > effective_at;

        select * into installment from public.aircraft_lease_installments
        where aircraft_lease_installments.contract_id = contract.id
          and aircraft_lease_installments.installment_number = installment_no;
        installment_exists := found;

        if installment_exists and installment.state = 'paid' then
            continue;
        end if;

        if installment_exists
           and installment.state = 'grace'
           and effective_at >= installment.grace_until
        then
            update public.aircraft_lease_installments set state = 'defaulted' where id = installment.id;
            update public.aircraft_lease_contracts set state = 'defaulted', terminated_at = effective_at
            where id = contract.id returning * into contract;
            update public.company_aircraft set is_usable = false where id = contract.aircraft_id;
            insert into private.aircraft_lease_events (
                contract_id, event_type, installment_number, effective_at, idempotency_key
            ) values (
                contract.id, 'defaulted', installment_no, effective_at, idempotency_key
            );
            exit;
        end if;

        select coalesce(sum(amount_minor), 0) into ledger_balance
        from private.financial_ledger_entries where subject_id = subject.subject_id;

        if ledger_balance >= contract.rent_minor then
            installment_id := case when installment_exists then installment.id else gen_random_uuid() end;
            select coalesce(max(sequence_number), 0) + 1 into next_sequence
            from private.financial_ledger_entries where subject_id = subject.subject_id;
            insert into private.financial_ledger_entries (
                subject_id, sequence_number, idempotency_key, entry_type, amount_minor, currency_code
            ) values (
                subject.subject_id, next_sequence, installment_id, 'aircraft_lease_rent', -contract.rent_minor, contract.currency_code
            ) returning * into ledger_entry;

            if not installment_exists then
                insert into public.aircraft_lease_installments (
                    id, contract_id, installment_number, due_at, amount_minor, currency_code,
                    state, paid_at, ledger_entry_id
                ) values (
                    installment_id, contract.id, installment_no, due, contract.rent_minor,
                    contract.currency_code, 'paid', effective_at, ledger_entry.id
                )
                returning * into installment;
            else
                update public.aircraft_lease_installments
                set state = 'paid', paid_at = effective_at, ledger_entry_id = ledger_entry.id
                where id = installment.id returning * into installment;
            end if;
            insert into private.aircraft_lease_events (contract_id, event_type, installment_number, effective_at, idempotency_key)
            values (contract.id, 'rent_paid', installment_no, effective_at, installment.id);
            if contract.state = 'grace' then
                update public.aircraft_lease_contracts set state = 'active' where id = contract.id returning * into contract;
            end if;
        else
            if not installment_exists then
                insert into public.aircraft_lease_installments (
                    contract_id, installment_number, due_at, amount_minor, currency_code, state, grace_until
                ) values (
                    contract.id, installment_no, due, contract.rent_minor, contract.currency_code, 'grace',
                    due + make_interval(hours => contract.grace_hours)
                ) returning * into installment;
                insert into private.aircraft_lease_events (contract_id, event_type, installment_number, effective_at, idempotency_key)
                values (contract.id, 'grace_started', installment_no, effective_at, installment.id);
            end if;

            if effective_at >= installment.grace_until then
                update public.aircraft_lease_installments set state = 'defaulted' where id = installment.id;
                update public.aircraft_lease_contracts set state = 'defaulted', terminated_at = effective_at
                where id = contract.id returning * into contract;
                update public.company_aircraft set is_usable = false where id = contract.aircraft_id;
                insert into private.aircraft_lease_events (contract_id, event_type, installment_number, effective_at, idempotency_key)
                values (contract.id, 'defaulted', installment_no, effective_at, idempotency_key);
            else
                update public.aircraft_lease_contracts set state = 'grace'
                where id = contract.id returning * into contract;
            end if;
            exit;
        end if;
    end loop;

    if contract.state = 'active' and effective_at >= contract.ends_at
       and (
           select count(*)
           from public.aircraft_lease_installments as paid_installments
           where paid_installments.contract_id = contract.id
             and paid_installments.state = 'paid'
       ) = 30
    then
        update public.aircraft_lease_contracts set state = 'expired', terminated_at = effective_at
        where id = contract.id returning * into contract;
        update public.company_aircraft set is_usable = false where id = contract.aircraft_id;
        insert into private.aircraft_lease_events (contract_id, event_type, effective_at, idempotency_key)
        values (contract.id, 'expired', effective_at, idempotency_key);
    end if;

    result := jsonb_build_object('contractId', contract.id, 'schemaVersion', 1, 'state', contract.state);
    insert into private.aircraft_lease_temporal_commands values (contract.id, idempotency_key, effective_at, result, clock_timestamp());
    return result;
end;
$$;

revoke all on function public.process_aircraft_lease(uuid, uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.process_aircraft_lease(uuid, uuid, timestamptz) to service_role;

create function public.terminate_aircraft_lease(owner_id uuid, contract_id uuid, idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
    contract public.aircraft_lease_contracts%rowtype;
    company public.companies%rowtype;
    existing private.aircraft_lease_termination_commands%rowtype;
    result jsonb;
    terminated timestamptz := transaction_timestamp();
begin
    if owner_id is null or contract_id is null or idempotency_key is null then
        raise invalid_parameter_value using message = 'Owner, contract and idempotency key are required.';
    end if;

    select * into company from public.companies
    where companies.owner_id = terminate_aircraft_lease.owner_id for update;
    if not found or not private.account_is_active(terminate_aircraft_lease.owner_id) then
        raise object_not_in_prerequisite_state using message = 'Aircraft lease is unavailable.';
    end if;

    select * into existing from private.aircraft_lease_termination_commands
    where aircraft_lease_termination_commands.owner_id = terminate_aircraft_lease.owner_id
      and aircraft_lease_termination_commands.idempotency_key = terminate_aircraft_lease.idempotency_key;
    if found then
        if existing.contract_id <> terminate_aircraft_lease.contract_id then
            raise invalid_parameter_value using message = 'Idempotency key was already used with a different contract.';
        end if;
        return existing.result;
    end if;

    select * into contract from public.aircraft_lease_contracts
    where id = terminate_aircraft_lease.contract_id and company_id = company.id for update;
    if not found or contract.state not in ('active', 'grace') then
        raise object_not_in_prerequisite_state using message = 'Aircraft lease cannot be terminated.';
    end if;

    update public.aircraft_lease_contracts set state = 'terminated', terminated_at = terminated
    where id = contract.id returning * into contract;
    update public.company_aircraft set is_usable = false where id = contract.aircraft_id;
    insert into private.aircraft_lease_events (contract_id, event_type, effective_at, idempotency_key)
    values (contract.id, 'terminated', terminated, idempotency_key);

    result := jsonb_build_object('contractId', contract.id, 'schemaVersion', 1, 'state', contract.state);
    insert into private.aircraft_lease_termination_commands values (owner_id, idempotency_key, contract.id, result, clock_timestamp());
    return result;
end;
$$;

revoke all on function public.terminate_aircraft_lease(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.terminate_aircraft_lease(uuid, uuid, uuid) to service_role;

comment on table public.aircraft_lease_contracts is 'Authoritative 30-day aircraft lease with immutable versioned terms and server transitions.';
comment on table public.aircraft_lease_installments is 'Deterministic daily lease obligations materialized in order by the privileged temporal command.';
comment on function public.process_aircraft_lease(uuid, uuid, timestamptz) is 'Manual service-role catch-up command; effective_at is privileged server authority, never client input.';
