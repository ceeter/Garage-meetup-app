-- Phase 1 in-app notifications only. This does not enable phone push notifications.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'general',
  reference_type text,
  reference_id uuid,
  group_id uuid references public.groups(id) on delete cascade,
  meet_id uuid references public.meets(id) on delete cascade,
  check_in_id uuid references public.check_ins(id) on delete cascade,
  reminder_offset_minutes integer,
  dedupe_key text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id, dedupe_key)
);

create index if not exists notifications_user_id_created_at_idx on public.notifications(user_id, created_at desc);
create index if not exists notifications_user_id_read_at_idx on public.notifications(user_id, read_at);
create index if not exists notifications_group_id_idx on public.notifications(group_id);
create index if not exists notifications_meet_id_idx on public.notifications(meet_id);
create index if not exists notifications_check_in_id_idx on public.notifications(check_in_id);

alter table public.notifications enable row level security;

drop policy if exists "users can read own notifications" on public.notifications;
drop policy if exists "users can insert own notifications" on public.notifications;
drop policy if exists "users can mark own notifications read" on public.notifications;
drop policy if exists "users can update own notifications" on public.notifications;

create policy "users can read own notifications" on public.notifications
  for select to authenticated using (auth.uid() = user_id);
create policy "users can insert own notifications" on public.notifications
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can update own notifications" on public.notifications
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.create_cruise_started_notifications(target_check_in_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  checkin_row public.check_ins%rowtype;
  group_name text;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Sign in required to create cruise notifications';
  end if;

  select * into checkin_row
  from public.check_ins
  where id = target_check_in_id;

  if not found then
    raise exception 'Cruise check-in not found';
  end if;

  if checkin_row.user_id <> auth.uid() then
    raise exception 'Only the cruise starter can notify crew members';
  end if;

  if checkin_row.group_id is null then
    return;
  end if;

  if not public.is_group_member(checkin_row.group_id) then
    raise exception 'Only crew members can notify this crew';
  end if;

  select name into group_name
  from public.groups
  where id = checkin_row.group_id;

  actor_name := coalesce(nullif(trim(checkin_row.display_name), ''), 'A crew member');

  insert into public.notifications (
    user_id,
    title,
    body,
    type,
    reference_type,
    reference_id,
    group_id,
    check_in_id,
    dedupe_key
  )
  select
    gm.user_id,
    'Cruise started',
    actor_name || ' started a cruise in ' || coalesce(group_name, 'your crew') || '.',
    'cruise_started',
    'check_in',
    checkin_row.id,
    checkin_row.group_id,
    checkin_row.id,
    'cruise_started:check_in:' || checkin_row.id::text
  from public.group_memberships gm
  where gm.group_id = checkin_row.group_id
    and gm.user_id <> checkin_row.user_id
  on conflict (user_id, dedupe_key) do nothing;
end;
$$;

grant execute on function public.create_cruise_started_notifications(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
