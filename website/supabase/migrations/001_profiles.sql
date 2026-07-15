-- W1 migration: profiles table with RLS-first setup.
-- Run in the Supabase SQL editor (or supabase CLI) BEFORE any signups.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text,
  created_at timestamptz not null default now(),
  waitlist_position serial,
  beta_status text not null default 'waitlist'
    check (beta_status in ('waitlist', 'invited', 'tester')),
  testflight_url text
);

-- RLS FIRST: enable before the table holds a single row. Default deny.
alter table public.profiles enable row level security;

-- Users can read only their own row.
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

-- Users can update only their own row, and only display_name
-- (column-level protection via a trigger below; policy limits row access).
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- No insert/delete policies: clients can never insert or delete rows.

-- Prevent users from changing anything except display_name.
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.id            is distinct from old.id
  or new.email         is distinct from old.email
  or new.created_at    is distinct from old.created_at
  or new.waitlist_position is distinct from old.waitlist_position
  or new.beta_status   is distinct from old.beta_status
  or new.testflight_url is distinct from old.testflight_url then
    raise exception 'Only display_name may be updated';
  end if;
  return new;
end;
$$;

create trigger protect_profile_columns
  before update on public.profiles
  for each row
  when (auth.uid() = old.id)  -- applies to end-user updates, not service role
  execute function public.protect_profile_columns();

-- Auto-create a profile row when a new auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'display_name'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
