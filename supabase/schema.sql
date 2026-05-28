-- Garage Circle private MVP shared tables.
-- Run this in the Supabase SQL editor for your project.

create extension if not exists pgcrypto;

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  year text default '',
  make text not null,
  model text not null,
  mods text default '',
  ig text default '',
  tt text default '',
  created_at timestamptz not null default now()
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

alter table public.members enable row level security;
alter table public.meets enable row level security;
alter table public.photo_drops enable row level security;
alter table public.announcements enable row level security;

-- Private friend-group MVP policy: anyone with the anon key can read/write these tables.
-- Keep your Supabase project URL/key shared only with your invited group until auth is added.
create policy "anon can read members" on public.members for select to anon using (true);
create policy "anon can insert members" on public.members for insert to anon with check (true);
create policy "anon can update members" on public.members for update to anon using (true) with check (true);
create policy "anon can delete members" on public.members for delete to anon using (true);

create policy "anon can read meets" on public.meets for select to anon using (true);
create policy "anon can insert meets" on public.meets for insert to anon with check (true);
create policy "anon can update meets" on public.meets for update to anon using (true) with check (true);
create policy "anon can delete meets" on public.meets for delete to anon using (true);

create policy "anon can read photo drops" on public.photo_drops for select to anon using (true);
create policy "anon can insert photo drops" on public.photo_drops for insert to anon with check (true);
create policy "anon can update photo drops" on public.photo_drops for update to anon using (true) with check (true);
create policy "anon can delete photo drops" on public.photo_drops for delete to anon using (true);

create policy "anon can read announcements" on public.announcements for select to anon using (true);
create policy "anon can insert announcements" on public.announcements for insert to anon with check (true);
create policy "anon can update announcements" on public.announcements for update to anon using (true) with check (true);
create policy "anon can delete announcements" on public.announcements for delete to anon using (true);
