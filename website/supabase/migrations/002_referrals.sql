-- Design pass migration: referral system.
-- Run in the Supabase SQL editor after 001_profiles.sql.

alter table public.profiles
  add column referral_code text unique not null default substr(md5(gen_random_uuid()::text), 1, 8),
  add column referred_by uuid references public.profiles (id);

-- Extend column protection: users may still only change display_name.
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.id                is distinct from old.id
  or new.email             is distinct from old.email
  or new.created_at        is distinct from old.created_at
  or new.waitlist_position is distinct from old.waitlist_position
  or new.beta_status       is distinct from old.beta_status
  or new.testflight_url    is distinct from old.testflight_url
  or new.referral_code     is distinct from old.referral_code
  or new.referred_by       is distinct from old.referred_by then
    raise exception 'Only display_name may be updated';
  end if;
  return new;
end;
$$;

-- Resolve ?ref= codes at signup time (metadata set by the client).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ref_id uuid;
begin
  select id into ref_id
  from public.profiles
  where referral_code = new.raw_user_meta_data ->> 'ref'
  limit 1;

  insert into public.profiles (id, email, display_name, referred_by)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'display_name',
    ref_id
  );
  return new;
end;
$$;

-- Users can't read other rows, so count referrals via security definer RPC.
create or replace function public.referral_stats()
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int from public.profiles where referred_by = auth.uid();
$$;
