create table public.companies (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users (id) on delete restrict,
    name text not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    constraint companies_one_per_owner unique (owner_id),
    constraint companies_name_trimmed check (name = btrim(name)),
    constraint companies_name_length check (char_length(name) between 2 and 80)
);

comment on table public.companies is
    'A virtual airline owned by exactly one authenticated user in the solo MVP.';
comment on column public.companies.owner_id is
    'Server-authoritative owner identity from Supabase Auth.';

alter table public.companies enable row level security;
alter table public.companies force row level security;

revoke all on table public.companies from anon;
revoke all on table public.companies from authenticated;
grant select, insert, update, delete on table public.companies to authenticated;

create policy companies_select_own
on public.companies
for select
to authenticated
using ((select auth.uid()) = owner_id);

create policy companies_insert_own
on public.companies
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

create policy companies_update_own
on public.companies
for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create policy companies_delete_own
on public.companies
for delete
to authenticated
using ((select auth.uid()) = owner_id);
