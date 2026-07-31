create table private.financial_ledger_subjects (
    subject_id uuid primary key default gen_random_uuid(),
    company_id uuid unique references public.companies (id) on delete restrict,
    created_at timestamptz not null default clock_timestamp(),
    anonymized_at timestamptz,
    constraint financial_ledger_subjects_lifecycle check (
        (company_id is not null and anonymized_at is null)
        or
        (company_id is null and anonymized_at is not null)
    )
);

create table private.financial_ledger_entries (
    id uuid primary key default gen_random_uuid(),
    subject_id uuid not null references private.financial_ledger_subjects (subject_id) on delete restrict,
    sequence_number bigint not null,
    idempotency_key uuid not null,
    entry_type text not null,
    amount_minor bigint not null,
    currency_code text not null,
    recorded_at timestamptz not null default clock_timestamp(),
    schema_version integer not null default 1,
    constraint financial_ledger_entries_sequence unique (subject_id, sequence_number),
    constraint financial_ledger_entries_idempotency unique (subject_id, idempotency_key),
    constraint financial_ledger_entries_one_opening unique (subject_id, entry_type),
    constraint financial_ledger_entries_first_sequence check (sequence_number = 1),
    constraint financial_ledger_entries_opening_type check (entry_type = 'opening_balance'),
    constraint financial_ledger_entries_amount check (
        amount_minor <> 0
        and amount_minor between -1000000000000000 and 1000000000000000
    ),
    constraint financial_ledger_entries_currency check (
        currency_code ~ '^[A-Z]{3}$'
    ),
    constraint financial_ledger_entries_schema_version check (schema_version = 1)
);

alter table private.financial_ledger_subjects enable row level security;
alter table private.financial_ledger_subjects force row level security;
alter table private.financial_ledger_entries enable row level security;
alter table private.financial_ledger_entries force row level security;

revoke all on table private.financial_ledger_subjects from public;
revoke all on table private.financial_ledger_subjects from anon;
revoke all on table private.financial_ledger_subjects from authenticated;
revoke all on table private.financial_ledger_entries from public;
revoke all on table private.financial_ledger_entries from anon;
revoke all on table private.financial_ledger_entries from authenticated;
revoke all on table private.financial_ledger_entries from service_role;

comment on table private.financial_ledger_subjects is
    'Private, detachable mapping between a company and its opaque financial ledger subject.';
comment on table private.financial_ledger_entries is
    'Append-only authoritative financial events without direct Auth or company identifiers.';

create function private.create_financial_ledger_subject()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into private.financial_ledger_subjects (company_id)
    values (new.id)
    on conflict (company_id) do nothing;
    return new;
end;
$$;

revoke all on function private.create_financial_ledger_subject() from public;
revoke all on function private.create_financial_ledger_subject() from anon;
revoke all on function private.create_financial_ledger_subject() from authenticated;

create trigger companies_create_financial_ledger_subject
after insert on public.companies
for each row
execute function private.create_financial_ledger_subject();

insert into private.financial_ledger_subjects (company_id)
select companies.id
from public.companies as companies
on conflict (company_id) do nothing;

create function private.anonymize_financial_ledger_subject()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update private.financial_ledger_subjects as subjects
    set company_id = null,
        anonymized_at = clock_timestamp()
    where subjects.company_id = old.id;
    return old;
end;
$$;

revoke all on function private.anonymize_financial_ledger_subject() from public;
revoke all on function private.anonymize_financial_ledger_subject() from anon;
revoke all on function private.anonymize_financial_ledger_subject() from authenticated;

create trigger companies_anonymize_financial_ledger_subject
before delete on public.companies
for each row
execute function private.anonymize_financial_ledger_subject();

create function private.reject_financial_ledger_entry_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise object_not_in_prerequisite_state using
        message = 'Financial ledger entries are append-only.';
end;
$$;

revoke all on function private.reject_financial_ledger_entry_mutation() from public;
revoke all on function private.reject_financial_ledger_entry_mutation() from anon;
revoke all on function private.reject_financial_ledger_entry_mutation() from authenticated;

create trigger financial_ledger_entries_reject_update_delete
before update or delete on private.financial_ledger_entries
for each row
execute function private.reject_financial_ledger_entry_mutation();

create trigger financial_ledger_entries_reject_truncate
before truncate on private.financial_ledger_entries
for each statement
execute function private.reject_financial_ledger_entry_mutation();

create function public.post_company_opening_balance(
    company_id uuid,
    idempotency_key uuid,
    amount_minor bigint,
    currency_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    company public.companies%rowtype;
    subject private.financial_ledger_subjects%rowtype;
    existing_entry private.financial_ledger_entries%rowtype;
    new_entry private.financial_ledger_entries%rowtype;
    normalized_currency text := upper(btrim(currency_code));
begin
    if company_id is null or idempotency_key is null then
        raise invalid_parameter_value using
            message = 'Company and idempotency key are required.';
    end if;

    if amount_minor is null
        or amount_minor = 0
        or amount_minor < -1000000000000000
        or amount_minor > 1000000000000000
    then
        raise invalid_parameter_value using
            message = 'Opening balance amount is invalid.';
    end if;

    if currency_code is null
        or currency_code <> normalized_currency
        or normalized_currency !~ '^[A-Z]{3}$'
    then
        raise invalid_parameter_value using
            message = 'Currency code must be an uppercase ISO 4217 code.';
    end if;

    select companies.*
    into company
    from public.companies as companies
    where companies.id = post_company_opening_balance.company_id
    for update;

    if not found or not private.account_is_active(company.owner_id) then
        raise object_not_in_prerequisite_state using
            message = 'Company ledger cannot be changed.';
    end if;

    select subjects.*
    into strict subject
    from private.financial_ledger_subjects as subjects
    where subjects.company_id = company.id
      and subjects.anonymized_at is null
    for update;

    select entries.*
    into existing_entry
    from private.financial_ledger_entries as entries
    where entries.subject_id = subject.subject_id
      and entries.idempotency_key = post_company_opening_balance.idempotency_key;

    if found then
        if existing_entry.entry_type <> 'opening_balance'
            or existing_entry.amount_minor <> post_company_opening_balance.amount_minor
            or existing_entry.currency_code <> normalized_currency
        then
            raise invalid_parameter_value using
                message = 'Idempotency key was already used with another payload.';
        end if;

        return jsonb_build_object(
            'entryId', existing_entry.id,
            'sequenceNumber', existing_entry.sequence_number,
            'entryType', existing_entry.entry_type,
            'amountMinor', existing_entry.amount_minor,
            'currencyCode', existing_entry.currency_code,
            'recordedAt', existing_entry.recorded_at,
            'schemaVersion', existing_entry.schema_version
        );
    end if;

    if exists (
        select 1
        from private.financial_ledger_entries as entries
        where entries.subject_id = subject.subject_id
          and entries.entry_type = 'opening_balance'
    ) then
        raise object_not_in_prerequisite_state using
            message = 'Company ledger is already open.';
    end if;

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
        1,
        idempotency_key,
        'opening_balance',
        amount_minor,
        normalized_currency
    )
    returning *
    into new_entry;

    return jsonb_build_object(
        'entryId', new_entry.id,
        'sequenceNumber', new_entry.sequence_number,
        'entryType', new_entry.entry_type,
        'amountMinor', new_entry.amount_minor,
        'currencyCode', new_entry.currency_code,
        'recordedAt', new_entry.recorded_at,
        'schemaVersion', new_entry.schema_version
    );
end;
$$;

revoke all on function public.post_company_opening_balance(uuid, uuid, bigint, text) from public;
revoke all on function public.post_company_opening_balance(uuid, uuid, bigint, text) from anon;
revoke all on function public.post_company_opening_balance(uuid, uuid, bigint, text) from authenticated;
grant execute on function public.post_company_opening_balance(uuid, uuid, bigint, text) to service_role;

create function public.get_company_ledger()
returns table (
    entry_id uuid,
    sequence_number bigint,
    entry_type text,
    amount_minor bigint,
    currency_code text,
    recorded_at timestamptz,
    schema_version integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    actor_id uuid := auth.uid();
begin
    if actor_id is null
        or coalesce(auth.jwt() ->> 'role', '') <> 'authenticated'
        or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
    then
        raise insufficient_privilege using
            message = 'Company ledger access is not permitted.';
    end if;

    return query
    select
        entries.id,
        entries.sequence_number,
        entries.entry_type,
        entries.amount_minor,
        entries.currency_code,
        entries.recorded_at,
        entries.schema_version
    from public.companies as companies
    join private.financial_ledger_subjects as subjects
      on subjects.company_id = companies.id
    join private.financial_ledger_entries as entries
      on entries.subject_id = subjects.subject_id
    where companies.owner_id = actor_id
    order by entries.sequence_number;
end;
$$;

revoke all on function public.get_company_ledger() from public;
revoke all on function public.get_company_ledger() from anon;
revoke all on function public.get_company_ledger() from authenticated;
grant execute on function public.get_company_ledger() to authenticated;
