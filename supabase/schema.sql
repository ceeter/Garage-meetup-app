-- CruiseCrew private MVP shared tables.
-- Run this in the Supabase SQL editor for your project.

create extension if not exists pgcrypto;

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  description text default '',
  is_public boolean not null default true,
  owner_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(slug)
);

create table if not exists public.group_memberships (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default now(),
  unique(group_id, user_id)
);


create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  code text unique not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  max_uses integer,
  use_count integer not null default 0,
  is_active boolean not null default true
);

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
  latitude double precision,
  longitude double precision,
  location_label text,
  geocoded_address text,
  geocode_provider text,
  place_id text,
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
  group_id uuid references public.groups(id) on delete set null,
  latitude double precision,
  longitude double precision,
  geocoded_address text,
  geocode_provider text,
  place_id text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  expires_at timestamp with time zone default now() + interval '4 hours',
  ended_at timestamp with time zone
);

create table if not exists public.cruise_joins (
  id uuid primary key default gen_random_uuid(),
  check_in_id uuid references public.check_ins(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(check_in_id, user_id)
);

create table if not exists public.photo_drops (
  id uuid primary key default gen_random_uuid(),
  meet_id uuid references public.meets(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  member_id uuid references public.members(id) on delete set null,
  group_id uuid references public.groups(id) on delete set null,
  image_url text not null,
  storage_path text,
  caption text default '',
  spot_label text default '',
  display_name text default '',
  car_label text default '',
  like_count integer not null default 0,
  dislike_count integer not null default 0,
  hidden_by_dislikes boolean not null default false,
  hidden_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.photo_reactions (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.photo_drops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('like', 'dislike')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(photo_id, user_id)
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

alter table public.groups add column if not exists slug text;
alter table public.groups add column if not exists description text default '';
alter table public.groups add column if not exists is_public boolean not null default true;
alter table public.groups add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.groups add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.groups add column if not exists updated_at timestamptz not null default now();
update public.groups
set slug = trim(both '-' from lower(regexp_replace(trim(name), '[^a-zA-Z0-9]+', '-', 'g'))) || '-' || left(id::text, 8)
where slug is null or slug = '';
alter table public.groups alter column slug set not null;
create unique index if not exists groups_slug_key on public.groups(slug);
alter table public.group_memberships add column if not exists role text not null default 'member';
alter table public.members add column if not exists user_id uuid unique references auth.users(id) on delete cascade;
alter table public.members add column if not exists updated_at timestamptz not null default now();
alter table public.meets add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.meets add column if not exists latitude double precision;
alter table public.meets add column if not exists longitude double precision;
alter table public.meets add column if not exists location_label text;
alter table public.meets add column if not exists geocoded_address text;
alter table public.meets add column if not exists geocode_provider text;
alter table public.meets add column if not exists place_id text;
alter table public.check_ins add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.check_ins add column if not exists display_name text;
alter table public.check_ins add column if not exists car_label text;
alter table public.check_ins add column if not exists location_text text;
alter table public.check_ins add column if not exists note text;
alter table public.check_ins add column if not exists meet_id uuid references public.meets(id) on delete set null;
alter table public.check_ins add column if not exists group_id uuid references public.groups(id) on delete set null;
alter table public.check_ins add column if not exists latitude double precision;
alter table public.check_ins add column if not exists longitude double precision;
alter table public.photo_drops add column if not exists like_count integer not null default 0;
alter table public.photo_drops add column if not exists dislike_count integer not null default 0;
alter table public.photo_drops add column if not exists hidden_by_dislikes boolean not null default false;
alter table public.photo_drops add column if not exists hidden_at timestamptz;
alter table public.check_ins add column if not exists geocoded_address text;
alter table public.check_ins add column if not exists geocode_provider text;
alter table public.check_ins add column if not exists place_id text;
alter table public.check_ins add column if not exists created_at timestamp with time zone default now();
alter table public.check_ins add column if not exists updated_at timestamp with time zone default now();
alter table public.meet_rsvps add column if not exists display_name text;
alter table public.photo_drops add column if not exists meet_id uuid references public.meets(id) on delete cascade;
alter table public.photo_drops add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.photo_drops add column if not exists member_id uuid references public.members(id) on delete set null;
alter table public.photo_drops add column if not exists group_id uuid references public.groups(id) on delete set null;
alter table public.photo_drops add column if not exists image_url text;
alter table public.photo_drops add column if not exists storage_path text;
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
alter table public.cruise_joins add column if not exists check_in_id uuid references public.check_ins(id) on delete cascade;
alter table public.cruise_joins add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.cruise_joins add column if not exists created_at timestamptz default now();

alter table public.group_invites add column if not exists group_id uuid references public.groups(id) on delete cascade;
alter table public.group_invites add column if not exists code text;
alter table public.group_invites add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.group_invites add column if not exists created_at timestamptz not null default now();
alter table public.group_invites add column if not exists expires_at timestamptz;
alter table public.group_invites add column if not exists max_uses integer;
alter table public.group_invites add column if not exists use_count integer not null default 0;
alter table public.group_invites add column if not exists is_active boolean not null default true;
alter table public.group_invites alter column group_id set not null;
alter table public.group_invites alter column code set not null;
create unique index if not exists group_invites_code_key on public.group_invites(code);
create index if not exists group_invites_group_id_idx on public.group_invites(group_id);
create index if not exists check_ins_expires_at_idx on public.check_ins(expires_at);
create unique index if not exists check_ins_user_id_key on public.check_ins(user_id);
create index if not exists check_ins_user_id_idx on public.check_ins(user_id);
create index if not exists check_ins_group_id_idx on public.check_ins(group_id);
create index if not exists cruise_joins_check_in_id_idx on public.cruise_joins(check_in_id);
create index if not exists cruise_joins_user_id_idx on public.cruise_joins(user_id);
create unique index if not exists cruise_joins_check_in_id_user_id_key on public.cruise_joins(check_in_id, user_id);
create index if not exists groups_owner_id_idx on public.groups(owner_id);
create index if not exists group_memberships_group_id_idx on public.group_memberships(group_id);
create index if not exists group_memberships_user_id_idx on public.group_memberships(user_id);
create index if not exists photo_drops_meet_id_idx on public.photo_drops(meet_id);
create index if not exists photo_drops_user_id_idx on public.photo_drops(user_id);
create index if not exists photo_drops_group_id_idx on public.photo_drops(group_id);
create index if not exists photo_drops_storage_path_idx on public.photo_drops(storage_path);
create index if not exists photo_drops_created_at_idx on public.photo_drops(created_at desc);
create index if not exists photo_reactions_photo_id_idx on public.photo_reactions(photo_id);
create index if not exists photo_reactions_user_id_idx on public.photo_reactions(user_id);
create unique index if not exists members_user_id_key on public.members(user_id) where user_id is not null;

-- Admin/owner controls: replace your_email_here with your signed-in Supabase Auth email
-- and keep this list in sync with ADMIN_EMAILS in index.html.
create or replace function public.is_admin_user()
returns boolean
language sql
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = any (array['chancecampbell97@live.com']);
$$;



create or replace function public.is_group_member(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_memberships gm
    where gm.group_id = target_group_id and gm.user_id = auth.uid()
  );
$$;

create or replace function public.is_group_admin(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_memberships gm
    where gm.group_id = target_group_id and gm.user_id = auth.uid() and gm.role in ('owner', 'admin')
  );
$$;

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


create or replace function public.create_owner_membership_for_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is not null then
    insert into public.group_memberships (group_id, user_id, role)
    values (new.id, new.owner_id, 'owner')
    on conflict (group_id, user_id) do update set role = 'owner';
  end if;
  return new;
end;
$$;

drop trigger if exists create_owner_membership_for_group on public.groups;
create trigger create_owner_membership_for_group
  after insert on public.groups
  for each row execute function public.create_owner_membership_for_group();


create or replace function public.redeem_group_invite(invite_code text)
returns table(group_id uuid, group_name text, already_member boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  invite_row public.group_invites%rowtype;
  inserted_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Sign in required to join a crew';
  end if;

  select * into invite_row
  from public.group_invites gi
  where upper(gi.code) = upper(trim(invite_code))
    and gi.is_active = true
    and (gi.expires_at is null or gi.expires_at > now())
    and (gi.max_uses is null or gi.use_count < gi.max_uses)
  for update;

  if not found then
    raise exception 'Invite code is invalid or expired';
  end if;

  insert into public.group_memberships (group_id, user_id, role)
  values (invite_row.group_id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  get diagnostics inserted_count = row_count;

  if inserted_count > 0 then
    update public.group_invites
    set use_count = use_count + 1
    where id = invite_row.id;
  end if;

  return query
    select g.id, g.name, inserted_count = 0
    from public.groups g
    where g.id = invite_row.group_id;
end;
$$;

-- Safe owner/admin crew member management helpers.
-- These RPCs intentionally perform permission checks server-side so the
-- frontend does not rely on fragile direct membership updates/deletes.

create or replace function public.update_group_member_role(
  target_group_id uuid,
  target_user_id uuid,
  new_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_membership public.group_memberships%rowtype;
  target_group public.groups%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in required to manage crew members';
  end if;

  if new_role not in ('admin', 'member') then
    raise exception 'Invalid member role';
  end if;

  select * into target_group
  from public.groups
  where id = target_group_id;

  if not found then
    raise exception 'Crew not found';
  end if;

  if not (public.is_group_admin(target_group_id) or public.is_admin_user()) then
    raise exception 'Only crew owners/admins can manage members';
  end if;

  select * into target_membership
  from public.group_memberships
  where group_id = target_group_id
    and user_id = target_user_id
  for update;

  if not found then
    raise exception 'Member not found in this crew';
  end if;

  if target_membership.role = 'owner' or target_membership.user_id = target_group.owner_id then
    raise exception 'The crew owner cannot be demoted';
  end if;

  update public.group_memberships
  set role = new_role
  where group_id = target_group_id
    and user_id = target_user_id;
end;
$$;

create or replace function public.remove_group_member(
  target_group_id uuid,
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_membership public.group_memberships%rowtype;
  target_group public.groups%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in required to manage crew members';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'Use Leave Crew to remove yourself';
  end if;

  select * into target_group
  from public.groups
  where id = target_group_id;

  if not found then
    raise exception 'Crew not found';
  end if;

  if not (public.is_group_admin(target_group_id) or public.is_admin_user()) then
    raise exception 'Only crew owners/admins can manage members';
  end if;

  select * into target_membership
  from public.group_memberships
  where group_id = target_group_id
    and user_id = target_user_id
  for update;

  if not found then
    raise exception 'Member not found in this crew';
  end if;

  if target_membership.role = 'owner' or target_membership.user_id = target_group.owner_id then
    raise exception 'The crew owner cannot be removed';
  end if;

  delete from public.group_memberships
  where group_id = target_group_id
    and user_id = target_user_id;
end;
$$;

grant execute on function public.update_group_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;


create or replace function public.can_leave_group(target_group_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.group_memberships own_membership
      where own_membership.group_id = target_group_id
        and own_membership.user_id = auth.uid()
    )
    and not (
      exists (
        select 1
        from public.group_memberships own_admin_membership
        join public.groups own_group on own_group.id = own_admin_membership.group_id
        where own_admin_membership.group_id = target_group_id
          and own_admin_membership.user_id = auth.uid()
          and (own_admin_membership.role in ('owner', 'admin') or own_admin_membership.user_id = own_group.owner_id)
      )
      and (
        select count(*) = 1
        from public.group_memberships admin_membership
        join public.groups g on g.id = admin_membership.group_id
        where admin_membership.group_id = target_group_id
          and (admin_membership.role in ('owner', 'admin') or admin_membership.user_id = g.owner_id)
      )
    );
$$;

create or replace function public.leave_group(target_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required to leave this crew';
  end if;

  if not public.can_leave_group(target_group_id) then
    raise exception 'Transfer ownership before leaving this crew.';
  end if;

  delete from public.group_memberships
  where group_id = target_group_id
    and user_id = auth.uid();
end;
$$;

grant execute on function public.can_leave_group(uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;

alter table public.groups enable row level security;
alter table public.group_memberships enable row level security;
alter table public.group_invites enable row level security;
alter table public.members enable row level security;
alter table public.meets enable row level security;
alter table public.meet_rsvps enable row level security;
alter table public.check_ins enable row level security;
alter table public.cruise_joins enable row level security;
alter table public.photo_drops enable row level security;
alter table public.announcements enable row level security;


-- Groups v1 policies: signed-in users can discover crews, create crews,
-- and safely manage only their own membership rows. Group admins/owners can
-- update group basics and manage memberships inside their crew.
drop policy if exists "authenticated can read groups" on public.groups;
drop policy if exists "users can create groups" on public.groups;
drop policy if exists "group owners and admins can update groups" on public.groups;
drop policy if exists "group owners can delete groups" on public.groups;
drop policy if exists "members can read group memberships" on public.group_memberships;
drop policy if exists "users can join groups as self" on public.group_memberships;
drop policy if exists "users can leave own group membership" on public.group_memberships;
drop policy if exists "group owners and admins can manage memberships" on public.group_memberships;

create policy "authenticated can read groups" on public.groups
  for select to authenticated using (true);
create policy "users can create groups" on public.groups
  for insert to authenticated with check (auth.uid() = owner_id);
create policy "group owners and admins can update groups" on public.groups
  for update to authenticated using (
    public.is_group_admin(id) or public.is_admin_user()
  ) with check (true);
create policy "group owners can delete groups" on public.groups
  for delete to authenticated using (owner_id = auth.uid() or public.is_admin_user());

create policy "members can read group memberships" on public.group_memberships
  for select to authenticated using (
    user_id = auth.uid() or public.is_group_member(group_id) or public.is_admin_user()
  );
create policy "users can join groups as self" on public.group_memberships
  for insert to authenticated with check (auth.uid() = user_id and role = 'member');
create policy "users can leave own group membership" on public.group_memberships
  for delete to authenticated using (
    public.is_admin_user()
    or (auth.uid() = user_id and public.can_leave_group(group_id))
  );
create policy "group owners and admins can manage memberships" on public.group_memberships
  for update to authenticated using (
    public.is_group_admin(group_id) or public.is_admin_user()
  ) with check (role in ('owner', 'admin', 'member'));


-- Group invite policies: owners/admins can create and manage invite codes,
-- while signed-in users can redeem active invite codes through redeem_group_invite().
drop policy if exists "group admins can read invites" on public.group_invites;
drop policy if exists "group admins can create invites" on public.group_invites;
drop policy if exists "group admins can update invites" on public.group_invites;
drop policy if exists "group admins can delete invites" on public.group_invites;
drop policy if exists "authenticated can read active invites" on public.group_invites;

create policy "group admins can read invites" on public.group_invites
  for select to authenticated using (public.is_group_admin(group_id) or public.is_admin_user());
create policy "authenticated can read active invites" on public.group_invites
  for select to authenticated using (
    is_active = true
    and (expires_at is null or expires_at > now())
    and (max_uses is null or use_count < max_uses)
  );
create policy "group admins can create invites" on public.group_invites
  for insert to authenticated with check (
    created_by = auth.uid()
    and public.is_group_admin(group_id)
  );
create policy "group admins can update invites" on public.group_invites
  for update to authenticated using (public.is_group_admin(group_id) or public.is_admin_user())
  with check (public.is_group_admin(group_id) or public.is_admin_user());
create policy "group admins can delete invites" on public.group_invites
  for delete to authenticated using (public.is_group_admin(group_id) or public.is_admin_user());

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

-- Cruise joins are separate from meet RSVPs. Signed-in users can see who is
-- joining active cruise spots and manage only their own join row.
drop policy if exists "authenticated can read cruise joins" on public.cruise_joins;
drop policy if exists "users can insert own cruise join" on public.cruise_joins;
drop policy if exists "users can delete own cruise join" on public.cruise_joins;

create policy "authenticated can read cruise joins" on public.cruise_joins
  for select to authenticated using (true);
create policy "users can insert own cruise join" on public.cruise_joins
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can delete own cruise join" on public.cruise_joins
  for delete to authenticated using (auth.uid() = user_id);

-- Meets are publicly readable, but only admin emails can create or manage meet rows.
drop policy if exists "anon can read meets" on public.meets;
drop policy if exists "anon can insert meets" on public.meets;
drop policy if exists "anon can update meets" on public.meets;
drop policy if exists "anon can delete meets" on public.meets;
drop policy if exists "authenticated can read meets" on public.meets;
drop policy if exists "anon and authenticated can read meets" on public.meets;
drop policy if exists "users can insert own meet" on public.meets;
drop policy if exists "users can update own meet" on public.meets;
drop policy if exists "users can delete own meet" on public.meets;
drop policy if exists "admins can insert meets" on public.meets;
drop policy if exists "admins can update meets" on public.meets;
drop policy if exists "admins can delete meets" on public.meets;

create policy "anon and authenticated can read meets" on public.meets
  for select to anon, authenticated using (true);
create policy "admins can insert meets" on public.meets
  for insert to authenticated with check (public.is_admin_user());
create policy "admins can update meets" on public.meets
  for update to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins can delete meets" on public.meets
  for delete to authenticated using (public.is_admin_user());

-- Photo drops are public to view; signed-in users manage their own drops, and admins can moderate deletes.

create or replace function public.set_photo_reaction_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_photo_reaction_updated_at on public.photo_reactions;
create trigger set_photo_reaction_updated_at
  before update on public.photo_reactions
  for each row execute function public.set_photo_reaction_updated_at();

create or replace function public.refresh_photo_drop_reaction_counts(target_photo_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.photo_drops as photo
  set
    like_count = counts.like_count,
    dislike_count = counts.dislike_count,
    hidden_by_dislikes = case
      when counts.dislike_count >= 10 then true
      else photo.hidden_by_dislikes
    end,
    hidden_at = case
      when counts.dislike_count >= 10 and photo.hidden_at is null then now()
      else photo.hidden_at
    end
  from (
    select
      count(*) filter (where reaction = 'like')::integer as like_count,
      count(*) filter (where reaction = 'dislike')::integer as dislike_count
    from public.photo_reactions
    where photo_id = target_photo_id
  ) as counts
  where photo.id = target_photo_id;
end;
$$;

create or replace function public.handle_photo_reaction_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_photo_drop_reaction_counts(old.photo_id);
    return old;
  end if;

  perform public.refresh_photo_drop_reaction_counts(new.photo_id);
  if tg_op = 'UPDATE' and old.photo_id is distinct from new.photo_id then
    perform public.refresh_photo_drop_reaction_counts(old.photo_id);
  end if;
  return new;
end;
$$;

drop trigger if exists handle_photo_reaction_counts on public.photo_reactions;
create trigger handle_photo_reaction_counts
  after insert or update or delete on public.photo_reactions
  for each row execute function public.handle_photo_reaction_counts();

update public.photo_drops as photo
set
  like_count = counts.like_count,
  dislike_count = counts.dislike_count,
  hidden_by_dislikes = case when counts.dislike_count >= 10 then true else photo.hidden_by_dislikes end,
  hidden_at = case when counts.dislike_count >= 10 and photo.hidden_at is null then now() else photo.hidden_at end
from (
  select
    photo.id,
    count(reactions.id) filter (where reactions.reaction = 'like')::integer as like_count,
    count(reactions.id) filter (where reactions.reaction = 'dislike')::integer as dislike_count
  from public.photo_drops as photo
  left join public.photo_reactions as reactions on reactions.photo_id = photo.id
  group by photo.id
) as counts
where photo.id = counts.id;

alter table public.photo_reactions enable row level security;

drop policy if exists "authenticated can read photo reactions" on public.photo_reactions;
drop policy if exists "users can insert own photo reaction" on public.photo_reactions;
drop policy if exists "users can update own photo reaction" on public.photo_reactions;
drop policy if exists "users can delete own photo reaction" on public.photo_reactions;

create policy "authenticated can read photo reactions" on public.photo_reactions
  for select to authenticated using (true);
create policy "users can insert own photo reaction" on public.photo_reactions
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can update own photo reaction" on public.photo_reactions
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users can delete own photo reaction" on public.photo_reactions
  for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "anon can read photo drops" on public.photo_drops;
drop policy if exists "anon can insert photo drops" on public.photo_drops;
drop policy if exists "anon can update photo drops" on public.photo_drops;
drop policy if exists "anon can delete photo drops" on public.photo_drops;
drop policy if exists "anon and authenticated can read photo drops" on public.photo_drops;
drop policy if exists "users can insert own photo drops" on public.photo_drops;
drop policy if exists "users can update own photo drops" on public.photo_drops;
drop policy if exists "users can delete own photo drops" on public.photo_drops;

create policy "anon and authenticated can read photo drops" on public.photo_drops
  for select to anon, authenticated using (
    hidden_by_dislikes is not true
    or auth.uid() = user_id
    or public.is_admin_user()
  );
create policy "users can insert own photo drops" on public.photo_drops
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can update own photo drops" on public.photo_drops
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users can delete own photo drops" on public.photo_drops
  for delete to authenticated using (auth.uid() = user_id or public.is_admin_user());

-- News/announcements are global across all of CruiseCrew. They are not scoped
-- by group_id or crew_id, so RLS should not require any crew/group membership.
drop policy if exists "anon can read announcements" on public.announcements;
drop policy if exists "anon can insert announcements" on public.announcements;
drop policy if exists "anon can update announcements" on public.announcements;
drop policy if exists "anon can delete announcements" on public.announcements;
drop policy if exists "admins can insert announcements" on public.announcements;
drop policy if exists "admins can update announcements" on public.announcements;
drop policy if exists "admins can delete announcements" on public.announcements;
drop policy if exists "announcements are globally readable" on public.announcements;
drop policy if exists "admins can create global announcements" on public.announcements;
drop policy if exists "admins can update global announcements" on public.announcements;
drop policy if exists "admins can delete global announcements" on public.announcements;

create policy "announcements are globally readable" on public.announcements
  for select to anon, authenticated using (true);
create policy "admins can create global announcements" on public.announcements
  for insert to authenticated with check (public.is_admin_user());
create policy "admins can update global announcements" on public.announcements
  for update to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy "admins can delete global announcements" on public.announcements
  for delete to authenticated using (public.is_admin_user());
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
-- Owner/admin/moderator controls for CruiseCrew.
-- The first owner row is intentionally inserted manually in Supabase SQL.

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'moderator')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  unique(user_id, role)
);

create index if not exists user_roles_user_id_idx on public.user_roles(user_id);
create index if not exists user_roles_role_idx on public.user_roles(role);

alter table public.photo_drops add column if not exists hidden_by_moderator boolean not null default false;
alter table public.photo_drops add column if not exists hidden_by_moderator_at timestamptz;
alter table public.photo_drops add column if not exists hidden_by_moderator_user_id uuid references auth.users(id);
create index if not exists photo_drops_hidden_by_moderator_idx on public.photo_drops(hidden_by_moderator);

create or replace function public.has_app_role(target_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role = target_role
    );
$$;

create or replace function public.is_owner_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_app_role('owner');
$$;

-- Replaces the previous email-only helper. The legacy owner email remains an
-- admin fallback so existing deployments do not lose access before owner role
-- rows are inserted.
create or replace function public.is_admin_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_app_role('owner')
    or public.has_app_role('admin')
    or lower(coalesce(auth.jwt() ->> 'email', '')) = any (array['chancecampbell97@live.com']);
$$;

create or replace function public.is_moderator_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_app_role('moderator');
$$;

create or replace function public.can_manage_photos()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_owner_user() or public.is_admin_user() or public.is_moderator_user();
$$;

create or replace function public.can_manage_meets()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_owner_user() or public.is_admin_user();
$$;

create or replace function public.can_manage_news()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_owner_user() or public.is_admin_user();
$$;

create or replace function public.can_manage_roles()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_owner_user();
$$;

grant execute on function public.has_app_role(text) to authenticated;
grant execute on function public.is_owner_user() to authenticated;
grant execute on function public.is_admin_user() to authenticated;
grant execute on function public.is_moderator_user() to authenticated;
grant execute on function public.can_manage_photos() to authenticated;
grant execute on function public.can_manage_meets() to authenticated;
grant execute on function public.can_manage_news() to authenticated;
grant execute on function public.can_manage_roles() to authenticated;

alter table public.user_roles enable row level security;

drop policy if exists "users can read own role" on public.user_roles;
drop policy if exists "owner can read all roles" on public.user_roles;
drop policy if exists "owner can assign admin moderator roles" on public.user_roles;
drop policy if exists "owner can remove admin moderator roles" on public.user_roles;

create policy "users can read own role" on public.user_roles
  for select to authenticated using (auth.uid() = user_id);
create policy "owner can read all roles" on public.user_roles
  for select to authenticated using (public.can_manage_roles());
create policy "owner can assign admin moderator roles" on public.user_roles
  for insert to authenticated with check (
    public.can_manage_roles()
    and auth.uid() is distinct from user_id
    and created_by = auth.uid()
    and role in ('admin', 'moderator')
  );
create policy "owner can remove admin moderator roles" on public.user_roles
  for delete to authenticated using (
    public.can_manage_roles()
    and auth.uid() is distinct from user_id
    and role in ('admin', 'moderator')
  );

-- Meets/news management follows app roles instead of frontend-only email checks.
drop policy if exists "admins can insert meets" on public.meets;
drop policy if exists "admins can update meets" on public.meets;
drop policy if exists "admins can delete meets" on public.meets;
create policy "admins can insert meets" on public.meets
  for insert to authenticated with check (public.can_manage_meets());
create policy "admins can update meets" on public.meets
  for update to authenticated using (public.can_manage_meets()) with check (public.can_manage_meets());
create policy "admins can delete meets" on public.meets
  for delete to authenticated using (public.can_manage_meets());

drop policy if exists "admins can create global announcements" on public.announcements;
drop policy if exists "admins can update global announcements" on public.announcements;
drop policy if exists "admins can delete global announcements" on public.announcements;
create policy "admins can create global announcements" on public.announcements
  for insert to authenticated with check (public.can_manage_news());
create policy "admins can update global announcements" on public.announcements
  for update to authenticated using (public.can_manage_news()) with check (public.can_manage_news());
create policy "admins can delete global announcements" on public.announcements
  for delete to authenticated using (public.can_manage_news());

-- Hidden photos remain in database/storage but are removed from the public feed.
drop policy if exists "anon and authenticated can read photo drops" on public.photo_drops;
drop policy if exists "staff can moderate photo drops" on public.photo_drops;
create policy "anon and authenticated can read photo drops" on public.photo_drops
  for select to anon, authenticated using (
    (
      hidden_by_dislikes is not true
      and hidden_by_moderator is not true
    )
    or auth.uid() = user_id
    or public.can_manage_photos()
  );
create policy "staff can moderate photo drops" on public.photo_drops
  for update to authenticated using (public.can_manage_photos()) with check (public.can_manage_photos());
