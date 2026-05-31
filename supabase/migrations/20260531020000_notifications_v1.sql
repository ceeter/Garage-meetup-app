-- CruiseCrew Notifications v1: in-app, user-specific notifications only.
-- This intentionally does not add native/mobile push notifications.

create extension if not exists pgcrypto;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  type text not null,
  title text not null,
  body text,
  entity_type text,
  entity_id uuid,
  crew_id uuid,
  meet_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications add column if not exists actor_id uuid references auth.users(id) on delete set null;
alter table public.notifications add column if not exists entity_type text;
alter table public.notifications add column if not exists entity_id uuid;
alter table public.notifications add column if not exists crew_id uuid;
alter table public.notifications add column if not exists meet_id uuid;
alter table public.notifications add column if not exists body text;
alter table public.notifications add column if not exists read_at timestamptz;
alter table public.notifications add column if not exists created_at timestamptz not null default now();

-- Legacy aliases used by older CruiseCrew builds. Keep them so old clients do not break.
alter table public.notifications add column if not exists reference_type text;
alter table public.notifications add column if not exists reference_id uuid;
alter table public.notifications add column if not exists group_id uuid references public.groups(id) on delete cascade;
alter table public.notifications add column if not exists check_in_id uuid references public.check_ins(id) on delete cascade;
alter table public.notifications add column if not exists reminder_offset_minutes integer;
alter table public.notifications add column if not exists dedupe_key text;

update public.notifications
set
  entity_type = coalesce(entity_type, reference_type),
  entity_id = coalesce(entity_id, reference_id),
  crew_id = coalesce(crew_id, group_id)
where entity_type is null or entity_id is null or crew_id is null;

create index if not exists notifications_user_created_idx on public.notifications(user_id, created_at desc);
create index if not exists notifications_user_unread_idx on public.notifications(user_id) where read_at is null;
create index if not exists notifications_crew_idx on public.notifications(crew_id);
create index if not exists notifications_meet_idx on public.notifications(meet_id);
create unique index if not exists notifications_user_dedupe_idx on public.notifications(user_id, dedupe_key) where dedupe_key is not null;

alter table public.notifications enable row level security;

revoke insert, update, delete on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update(read_at) on public.notifications to authenticated;

-- Existing policy names are dropped so v1 has one clear RLS contract.
drop policy if exists "users can read own notifications" on public.notifications;
drop policy if exists "users can insert own notifications" on public.notifications;
drop policy if exists "users can mark own notifications read" on public.notifications;
drop policy if exists "users can update own notifications" on public.notifications;
drop policy if exists "users can delete own notifications" on public.notifications;

create policy "users can read own notifications" on public.notifications
  for select to authenticated using (auth.uid() = user_id);

create policy "users can mark own notifications read" on public.notifications
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.notification_display_name(target_user_id uuid, fallback_name text default null)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(trim(fallback_name), ''),
    (select nullif(trim(m.name), '') from public.members m where m.user_id = target_user_id order by m.created_at desc limit 1),
    'Someone'
  );
$$;

create or replace function public.create_cruise_started_notifications(target_check_in_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  checkin_row public.check_ins%rowtype;
  actor_name text;
begin
  select * into checkin_row
  from public.check_ins
  where id = target_check_in_id;

  if not found or checkin_row.user_id is null or checkin_row.group_id is null then
    return;
  end if;

  if checkin_row.ended_at is not null
    or (checkin_row.expires_at is not null and checkin_row.expires_at <= now()) then
    return;
  end if;

  if auth.uid() is not null and auth.uid() <> checkin_row.user_id then
    raise exception 'Only the cruise starter can notify crew members';
  end if;

  actor_name := public.notification_display_name(checkin_row.user_id, checkin_row.display_name);
  if actor_name = 'Someone' then
    actor_name := 'A crew member';
  end if;

  insert into public.notifications (
    user_id, actor_id, type, title, body,
    entity_type, entity_id, reference_type, reference_id,
    crew_id, group_id, meet_id, check_in_id, dedupe_key
  )
  select
    gm.user_id,
    checkin_row.user_id,
    'cruise_started',
    actor_name || ' started cruising',
    'A crew member is live in Cruise Mode.',
    'check_in',
    checkin_row.id,
    'check_in',
    checkin_row.id,
    checkin_row.group_id,
    checkin_row.group_id,
    checkin_row.meet_id,
    checkin_row.id,
    'cruise_started:' || checkin_row.user_id::text || ':' || checkin_row.group_id::text || ':' || checkin_row.id::text
  from public.group_memberships gm
  where gm.group_id = checkin_row.group_id
    and gm.user_id <> checkin_row.user_id
    and not exists (
      select 1
      from public.notifications n
      where n.user_id = gm.user_id
        and n.actor_id = checkin_row.user_id
        and n.type = 'cruise_started'
        and n.crew_id = checkin_row.group_id
        and n.created_at > now() - interval '45 minutes'
    )
  on conflict do nothing;
end;
$$;

grant execute on function public.create_cruise_started_notifications(uuid) to authenticated;

create or replace function public.create_meet_checkin_notifications(target_check_in_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  checkin_row public.check_ins%rowtype;
  meet_row public.meets%rowtype;
  actor_name text;
begin
  select * into checkin_row
  from public.check_ins
  where id = target_check_in_id;

  if not found or checkin_row.user_id is null or checkin_row.meet_id is null then
    return;
  end if;

  if checkin_row.ended_at is not null
    or (checkin_row.expires_at is not null and checkin_row.expires_at <= now()) then
    return;
  end if;

  if auth.uid() is not null and auth.uid() <> checkin_row.user_id then
    raise exception 'Only the checked-in user can notify RSVP’d members';
  end if;

  select * into meet_row
  from public.meets
  where id = checkin_row.meet_id;

  if not found then
    return;
  end if;

  actor_name := public.notification_display_name(checkin_row.user_id, checkin_row.display_name);

  insert into public.notifications (
    user_id, actor_id, type, title, body,
    entity_type, entity_id, reference_type, reference_id,
    crew_id, group_id, meet_id, check_in_id, dedupe_key
  )
  select
    r.user_id,
    checkin_row.user_id,
    'meet_checkin',
    actor_name || ' checked in at ' || meet_row.title,
    case
      when checkin_row.group_id is null then 'Someone is at a meet you RSVP’d to.'
      else 'Someone from your crew is at a meet you RSVP’d to.'
    end,
    'check_in',
    checkin_row.id,
    'check_in',
    checkin_row.id,
    checkin_row.group_id,
    checkin_row.group_id,
    checkin_row.meet_id,
    checkin_row.id,
    'meet_checkin:' || checkin_row.user_id::text || ':' || checkin_row.meet_id::text
  from public.meet_rsvps r
  where r.meet_id = checkin_row.meet_id
    and r.status in ('going', 'maybe')
    and r.user_id <> checkin_row.user_id
    and (
      checkin_row.group_id is null
      or exists (
        select 1
        from public.group_memberships gm
        where gm.group_id = checkin_row.group_id
          and gm.user_id = r.user_id
      )
    )
  on conflict do nothing;
end;
$$;

grant execute on function public.create_meet_checkin_notifications(uuid) to authenticated;

create or replace function public.create_photo_liked_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  photo_row public.photo_drops%rowtype;
  actor_name text;
begin
  if tg_op = 'UPDATE' and old.reaction = 'like' then
    return new;
  end if;

  if new.reaction <> 'like' then
    return new;
  end if;

  select * into photo_row
  from public.photo_drops
  where id = new.photo_id;

  if not found or photo_row.user_id is null or photo_row.user_id = new.user_id then
    return new;
  end if;

  actor_name := public.notification_display_name(new.user_id, null);

  insert into public.notifications (
    user_id, actor_id, type, title, body,
    entity_type, entity_id, reference_type, reference_id,
    crew_id, group_id, meet_id, dedupe_key
  ) values (
    photo_row.user_id,
    new.user_id,
    'photo_liked',
    actor_name || ' liked your photo',
    'Your photo got some love 🔥',
    'photo',
    photo_row.id,
    'photo',
    photo_row.id,
    photo_row.group_id,
    photo_row.group_id,
    photo_row.meet_id,
    'photo_liked:' || new.user_id::text || ':' || photo_row.id::text
  )
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists create_photo_liked_notification on public.photo_reactions;
create trigger create_photo_liked_notification
  after insert or update of reaction on public.photo_reactions
  for each row execute function public.create_photo_liked_notification();

create or replace function public.create_check_in_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  was_active boolean;
  is_active boolean;
  meet_changed boolean;
begin
  was_active := tg_op = 'UPDATE' and old.ended_at is null and coalesce(old.expires_at, now()) > now();
  is_active := new.ended_at is null and coalesce(new.expires_at, now()) > now();
  meet_changed := tg_op = 'INSERT' or old.meet_id is distinct from new.meet_id;

  if not is_active then
    return new;
  end if;

  if new.meet_id is not null and (meet_changed or not was_active) then
    perform public.create_meet_checkin_notifications(new.id);
  elsif new.group_id is not null and (tg_op = 'INSERT' or not was_active) then
    perform public.create_cruise_started_notifications(new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists create_check_in_notifications on public.check_ins;
create trigger create_check_in_notifications
  after insert or update of meet_id, group_id, ended_at, expires_at on public.check_ins
  for each row execute function public.create_check_in_notifications();

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
