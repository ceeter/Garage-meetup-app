-- CruiseCrew private MVP shared tables.
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
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);


create table if not exists public.meet_rsvps (
  id uuid primary key default gen_random_uuid(),
  meet_id uuid references public.meets(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  status text not null check (status in ('going', 'maybe', 'not_going')),
  display_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(meet_id, user_id)
);


create table if not exists public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  display_name text,
  car_label text,
  location_text text,
  note text,
  meet_id uuid references public.meets(id) on delete set null,
  created_at timestamp with time zone default now(),
  expires_at timestamp with time zone default now() + interval '4 hours',
  ended_at timestamp with time zone
);

create table if not exists public.photo_drops (
  id uuid primary key default gen_random_uuid(),
  meet_id uuid references public.meets(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  member_id uuid references public.members(id) on delete set null,
  image_url text not null,
  caption text default '',
  spot_label text default '',
  display_name text default '',
  car_label text default '',
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
alter table public.meets add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.check_ins add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.check_ins add column if not exists display_name text;
alter table public.check_ins add column if not exists car_label text;
alter table public.check_ins add column if not exists location_text text;
alter table public.check_ins add column if not exists note text;
alter table public.check_ins add column if not exists meet_id uuid references public.meets(id) on delete set null;
alter table public.check_ins add column if not exists created_at timestamp with time zone default now();
alter table public.meet_rsvps add column if not exists display_name text;
alter table public.photo_drops add column if not exists meet_id uuid references public.meets(id) on delete cascade;
alter table public.photo_drops add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.photo_drops add column if not exists member_id uuid references public.members(id) on delete set null;
alter table public.photo_drops add column if not exists image_url text;
alter table public.photo_drops add column if not exists caption text default '';
alter table public.photo_drops add column if not exists spot_label text default '';
alter table public.photo_drops add column if not exists display_name text default '';
alter table public.photo_drops add column if not exists car_label text default '';
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'photo_drops' and column_name = 'url'
  ) then
    execute 'update public.photo_drops set image_url = coalesce(nullif(image_url, ''''), url, '''') where image_url is null';
  else
    update public.photo_drops set image_url = '' where image_url is null;
  end if;
end $$;
alter table public.photo_drops alter column image_url set default '';
alter table public.photo_drops alter column image_url set not null;
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'photo_drops' and column_name = 'author'
  ) then
    alter table public.photo_drops alter column author set default '';
  end if;
end $$;
alter table public.check_ins add column if not exists expires_at timestamp with time zone default now() + interval '4 hours';
alter table public.check_ins add column if not exists ended_at timestamp with time zone;
create index if not exists check_ins_expires_at_idx on public.check_ins(expires_at);
create index if not exists check_ins_user_id_idx on public.check_ins(user_id);
create index if not exists photo_drops_meet_id_idx on public.photo_drops(meet_id);
create index if not exists photo_drops_user_id_idx on public.photo_drops(user_id);
create index if not exists photo_drops_created_at_idx on public.photo_drops(created_at desc);
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
alter table public.meet_rsvps enable row level security;
alter table public.check_ins enable row level security;
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


-- Meet RSVP policy: anyone with the app link can read RSVP activity,
-- but signed-in users can manage only their own RSVP row.
drop policy if exists "authenticated can read meet rsvps" on public.meet_rsvps;
drop policy if exists "anon and authenticated can read meet rsvps" on public.meet_rsvps;
drop policy if exists "users can insert own meet rsvp" on public.meet_rsvps;
drop policy if exists "users can update own meet rsvp" on public.meet_rsvps;
drop policy if exists "users can delete own meet rsvp" on public.meet_rsvps;

create policy "anon and authenticated can read meet rsvps" on public.meet_rsvps
  for select to anon, authenticated using (true);
create policy "users can insert own meet rsvp" on public.meet_rsvps
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can update own meet rsvp" on public.meet_rsvps
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users can delete own meet rsvp" on public.meet_rsvps
  for delete to authenticated using (auth.uid() = user_id);


-- Check-in policy: anyone with the app link can read check-in activity,
-- but signed-in users can manage only their own row.
drop policy if exists "authenticated can read active check ins" on public.check_ins;
drop policy if exists "anon and authenticated can read check ins" on public.check_ins;
drop policy if exists "users can insert own check in" on public.check_ins;
drop policy if exists "users can update own check in" on public.check_ins;
drop policy if exists "users can delete own check in" on public.check_ins;

create policy "anon and authenticated can read check ins" on public.check_ins
  for select to anon, authenticated using (true);
create policy "users can insert own check in" on public.check_ins
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can update own check in" on public.check_ins
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users can delete own check in" on public.check_ins
  for delete to authenticated using (auth.uid() = user_id);

-- Meets are publicly readable, but signed-in users can only create or manage their own meet rows.
drop policy if exists "anon can read meets" on public.meets;
drop policy if exists "anon can insert meets" on public.meets;
drop policy if exists "anon can update meets" on public.meets;
drop policy if exists "anon can delete meets" on public.meets;
drop policy if exists "authenticated can read meets" on public.meets;
drop policy if exists "anon and authenticated can read meets" on public.meets;
drop policy if exists "users can insert own meet" on public.meets;
drop policy if exists "users can update own meet" on public.meets;
drop policy if exists "users can delete own meet" on public.meets;

create policy "anon and authenticated can read meets" on public.meets
  for select to anon, authenticated using (true);
create policy "users can insert own meet" on public.meets
  for insert to authenticated with check (auth.uid() = created_by);
create policy "users can update own meet" on public.meets
  for update to authenticated using (auth.uid() = created_by) with check (auth.uid() = created_by);
create policy "users can delete own meet" on public.meets
  for delete to authenticated using (auth.uid() = created_by);

-- Photo drops are public to view, but only signed-in users can create or manage their own drops.
drop policy if exists "anon can read photo drops" on public.photo_drops;
drop policy if exists "anon can insert photo drops" on public.photo_drops;
drop policy if exists "anon can update photo drops" on public.photo_drops;
drop policy if exists "anon can delete photo drops" on public.photo_drops;
drop policy if exists "anon and authenticated can read photo drops" on public.photo_drops;
drop policy if exists "users can insert own photo drops" on public.photo_drops;
drop policy if exists "users can update own photo drops" on public.photo_drops;
drop policy if exists "users can delete own photo drops" on public.photo_drops;

create policy "anon and authenticated can read photo drops" on public.photo_drops
  for select to anon, authenticated using (true);
create policy "users can insert own photo drops" on public.photo_drops
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can update own photo drops" on public.photo_drops
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users can delete own photo drops" on public.photo_drops
  for delete to authenticated using (auth.uid() = user_id);

create policy "anon can read announcements" on public.announcements for select to anon, authenticated using (true);
create policy "anon can insert announcements" on public.announcements for insert to anon, authenticated with check (true);
create policy "anon can update announcements" on public.announcements for update to anon, authenticated using (true) with check (true);
create policy "anon can delete announcements" on public.announcements for delete to anon, authenticated using (true);
