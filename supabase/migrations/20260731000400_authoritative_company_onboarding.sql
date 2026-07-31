create table private.company_onboarding_commands (
    owner_id uuid not null references auth.users (id) on delete cascade,
    idempotency_key uuid not null,
    request_hash text not null,
    company_id uuid not null references public.companies (id) on delete cascade,
    response jsonb not null,
    created_at timestamptz not null default clock_timestamp(),
    primary key (owner_id, idempotency_key),
    constraint company_onboarding_commands_request_hash check (
        request_hash ~ '^[0-9a-f]{64}$'
    ),
    constraint company_onboarding_commands_response_version check (
        response ->> 'schemaVersion' = '1'
    )
);

alter table private.company_onboarding_commands enable row level security;
alter table private.company_onboarding_commands force row level security;

revoke all on table private.company_onboarding_commands from public;
revoke all on table private.company_onboarding_commands from anon;
revoke all on table private.company_onboarding_commands from authenticated;
revoke all on table private.company_onboarding_commands from service_role;

comment on table private.company_onboarding_commands is
    'Temporary server-only idempotency records removed with the Auth owner or company.';

revoke insert, update, delete on table public.companies from authenticated;

drop policy companies_insert_own on public.companies;
drop policy companies_update_own on public.companies;
drop policy companies_delete_own on public.companies;

create function public.create_company_with_opening_balance(
    owner_id uuid,
    idempotency_key uuid,
    company_name text,
    opening_amount_minor bigint,
    currency_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    locked_owner_id uuid;
    normalized_name text := btrim(company_name);
    normalized_currency text := upper(btrim(currency_code));
    request_hash text;
    existing_command private.company_onboarding_commands%rowtype;
    existing_company_id uuid;
    new_company public.companies%rowtype;
    opening_response jsonb;
    response jsonb;
begin
    if owner_id is null or idempotency_key is null then
        raise invalid_parameter_value using
            message = 'Owner and idempotency key are required.';
    end if;

    if company_name is null
        or company_name <> normalized_name
        or char_length(normalized_name) not between 2 and 80 then
        raise invalid_parameter_value using
            message = 'Company name must be trimmed and contain between 2 and 80 characters.';
    end if;

    if opening_amount_minor is null
        or opening_amount_minor = 0
        or opening_amount_minor < -1000000000000000
        or opening_amount_minor > 1000000000000000 then
        raise invalid_parameter_value using
            message = 'Opening amount is outside the supported range.';
    end if;

    if currency_code is null
        or currency_code <> normalized_currency
        or normalized_currency !~ '^[A-Z]{3}$' then
        raise invalid_parameter_value using
            message = 'Currency must be an uppercase ISO 4217 code.';
    end if;

    select users.id
    into locked_owner_id
    from auth.users as users
    where users.id = create_company_with_opening_balance.owner_id
      and not coalesce(users.is_anonymous, false)
    for update;

    if not found then
        raise insufficient_privilege using
            message = 'Company owner is not eligible.';
    end if;

    request_hash := encode(
        extensions.digest(
            convert_to(
                jsonb_build_object(
                    'companyName', normalized_name,
                    'currencyCode', normalized_currency,
                    'openingAmountMinor', opening_amount_minor,
                    'ownerId', locked_owner_id
                )::text,
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    );

    select commands.*
    into existing_command
    from private.company_onboarding_commands as commands
    where commands.owner_id = locked_owner_id
      and commands.idempotency_key = create_company_with_opening_balance.idempotency_key;

    if found then
        if existing_command.request_hash <> request_hash then
            raise invalid_parameter_value using
                message = 'Idempotency key was already used with a different payload.';
        end if;

        return existing_command.response;
    end if;

    if not private.account_is_active(locked_owner_id) then
        raise object_not_in_prerequisite_state using
            message = 'Account deletion is pending.';
    end if;

    select companies.id
    into existing_company_id
    from public.companies as companies
    where companies.owner_id = locked_owner_id;

    if found then
        raise object_not_in_prerequisite_state using
            message = 'Company already exists.';
    end if;

    insert into public.companies (owner_id, name)
    values (locked_owner_id, normalized_name)
    returning * into new_company;

    opening_response := public.post_company_opening_balance(
        new_company.id,
        create_company_with_opening_balance.idempotency_key,
        opening_amount_minor,
        normalized_currency
    );

    response := jsonb_build_object(
        'schemaVersion', 1,
        'companyId', new_company.id,
        'openingEntryId', opening_response ->> 'entryId',
        'state', 'active'
    );

    insert into private.company_onboarding_commands (
        owner_id,
        idempotency_key,
        request_hash,
        company_id,
        response
    )
    values (
        locked_owner_id,
        create_company_with_opening_balance.idempotency_key,
        request_hash,
        new_company.id,
        response
    );

    return response;
end;
$$;

revoke all on function public.create_company_with_opening_balance(uuid, uuid, text, bigint, text) from public;
revoke all on function public.create_company_with_opening_balance(uuid, uuid, text, bigint, text) from anon;
revoke all on function public.create_company_with_opening_balance(uuid, uuid, text, bigint, text) from authenticated;
grant execute on function public.create_company_with_opening_balance(uuid, uuid, text, bigint, text) to service_role;
