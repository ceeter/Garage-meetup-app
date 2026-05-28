-- Garage Circle private MVP shared tables.
-- Run this in the Supabase SQL editor for your project.

create extension if not exists pgcrypto;

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  name text not null,
  year text default '',
  make text not null,
  model text not null,
  mods text default '',
  ig text default '',
  tt text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.meets (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  date date not null,
  time time,
  location text not null,
  description text default '',
  rsvp jsonb not null default '{"going":0,"maybe":0,"cantgo":0}'::jsonb,
  my_rsvp text,
  checked_in boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.photo_drops (
  id uuid primary key default gen_random_uuid(),
  url text default '',
  emoji text default '📸',
  caption text not null,
  author text not null,
  car text default 'Unknown',
  date date not null default current_date,
  wide boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  text text not null,
  type text not null default 'info' check (type in ('info', 'warning', 'alert')),
  author text not null default 'Admin',
  date date not null default current_date,
  created_at timestamptz not null default now()
);

alter table public.members add column if not exists user_id uuid unique references auth.users(id) on delete cascade;
alter table public.members add column if not exists updated_at timestamptz not null default now();
create unique index if not exists members_user_id_key on public.members(user_id) where user_id is not null;

create or replace function public.set_member_user_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is null then
    new.user_id = auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists set_member_user_id on public.members;
create trigger set_member_user_id
  before insert on public.members
  for each row execute function public.set_member_user_id();

alter table public.members enable row level security;
alter table public.meets enable row level security;
alter table public.photo_drops enable row level security;
alter table public.announcements enable row level security;

-- Garage profile policy: anyone with the app link can read the garage list,
-- but each profile row can only be inserted, updated, or deleted by its owner.
drop policy if exists "anon can read members" on public.members;
drop policy if exists "anon can insert members" on public.members;
drop policy if exists "anon can update members" on public.members;
drop policy if exists "anon can delete members" on public.members;
drop policy if exists "authenticated can read members" on public.members;
drop policy if exists "anon and authenticated can read members" on public.members;
drop policy if exists "users can insert own member profile" on public.members;
drop policy if exists "users can update own member profile" on public.members;
drop policy if exists "users can delete own member profile" on public.members;

create policy "anon and authenticated can read members" on public.members
  for select to anon, authenticated using (true);
create policy "users can insert own member profile" on public.members
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can update own member profile" on public.members
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users can delete own member profile" on public.members
  for delete to authenticated using (auth.uid() = user_id);

-- Private friend-group MVP policy for shared non-profile tables: anyone with the anon key can read/write.
create policy "anon can read meets" on public.meets for select to anon, authenticated using (true);
create policy "anon can insert meets" on public.meets for insert to anon, authenticated with check (true);
create policy "anon can update meets" on public.meets for update to anon, authenticated using (true) with check (true);
create policy "anon can delete meets" on public.meets for delete to anon, authenticated using (true);

create policy "anon can read photo drops" on public.photo_drops for select to anon, authenticated using (true);
create policy "anon can insert photo drops" on public.photo_drops for insert to anon, authenticated with check (true);
create policy "anon can update photo drops" on public.photo_drops for update to anon, authenticated using (true) with check (true);
create policy "anon can delete photo drops" on public.photo_drops for delete to anon, authenticated using (true);

create policy "anon can read announcements" on public.announcements for select to anon, authenticated using (true);
create policy "anon can insert announcements" on public.announcements for insert to anon, authenticated with check (true);
create policy "anon can update announcements" on public.announcements for update to anon, authenticated using (true) with check (true);
create policy "anon can delete announcements" on public.announcements for delete to anon, authenticated using (true);
