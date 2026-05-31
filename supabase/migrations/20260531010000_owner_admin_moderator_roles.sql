-- Owner/admin/moderator controls for CruiseCrew.
-- The first owner row is intentionally inserted manually in Supabase SQL.

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'moderator')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  unique(user_id)
);

-- If an earlier version allowed multiple roles per user, keep the highest role.
with ranked_roles as (
  select
    id,
    row_number() over (
      partition by user_id
      order by case role when 'owner' then 3 when 'admin' then 2 when 'moderator' then 1 else 0 end desc,
               created_at asc,
               id asc
    ) as role_rank
  from public.user_roles
)
delete from public.user_roles ur
using ranked_roles rr
where ur.id = rr.id
  and rr.role_rank > 1;

alter table public.user_roles drop constraint if exists user_roles_user_id_role_key;
drop index if exists public.user_roles_user_id_role_key;
create unique index if not exists user_roles_user_id_key on public.user_roles(user_id);
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

-- Temporary email fallback preserves current access until the owner role is
-- inserted and tested. Remove this email fallback after that verification.
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

create or replace function public.set_user_app_role(target_user_id uuid, new_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required to manage roles';
  end if;

  if not public.can_manage_roles() then
    raise exception 'Only the owner can manage app roles';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'You cannot change your own app role';
  end if;

  if new_role not in ('admin', 'moderator') then
    raise exception 'App role must be admin or moderator';
  end if;

  if exists (select 1 from public.user_roles where user_id = target_user_id and role = 'owner') then
    raise exception 'The owner role cannot be changed through the app';
  end if;

  insert into public.user_roles (user_id, role, created_by)
  values (target_user_id, new_role, auth.uid())
  on conflict (user_id) do update
    set role = excluded.role,
        created_by = excluded.created_by,
        created_at = now()
    where public.user_roles.role <> 'owner';
end;
$$;

create or replace function public.remove_user_app_role(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required to manage roles';
  end if;

  if not public.can_manage_roles() then
    raise exception 'Only the owner can manage app roles';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'You cannot remove your own app role';
  end if;

  if exists (select 1 from public.user_roles where user_id = target_user_id and role = 'owner') then
    raise exception 'The owner role cannot be removed through the app';
  end if;

  delete from public.user_roles
  where user_id = target_user_id
    and role in ('admin', 'moderator');
end;
$$;

create or replace function public.moderate_photo_drop(target_photo_id uuid, should_hide boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required to moderate photos';
  end if;

  if not public.can_manage_photos() then
    raise exception 'Only owner, admin, or moderator can moderate photos';
  end if;

  update public.photo_drops
  set hidden_by_moderator = should_hide,
      hidden_by_moderator_at = case when should_hide then now() else null end,
      hidden_by_moderator_user_id = case when should_hide then auth.uid() else null end
  where id = target_photo_id;

  if not found then
    raise exception 'Photo drop not found';
  end if;
end;
$$;

grant execute on function public.has_app_role(text) to authenticated;
grant execute on function public.is_owner_user() to authenticated;
grant execute on function public.is_admin_user() to authenticated;
grant execute on function public.is_moderator_user() to authenticated;
grant execute on function public.can_manage_photos() to authenticated;
grant execute on function public.can_manage_meets() to authenticated;
grant execute on function public.can_manage_news() to authenticated;
grant execute on function public.can_manage_roles() to authenticated;
grant execute on function public.set_user_app_role(uuid, text) to authenticated;
grant execute on function public.remove_user_app_role(uuid) to authenticated;
grant execute on function public.moderate_photo_drop(uuid, boolean) to authenticated;

alter table public.user_roles enable row level security;

drop policy if exists "users can read own role" on public.user_roles;
drop policy if exists "owner can read all roles" on public.user_roles;
drop policy if exists "owner can assign admin moderator roles" on public.user_roles;
drop policy if exists "owner can remove admin moderator roles" on public.user_roles;

create policy "users can read own role" on public.user_roles
  for select to authenticated using (auth.uid() = user_id);
create policy "owner can read all roles" on public.user_roles
  for select to authenticated using (public.can_manage_roles());

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
drop policy if exists "anon and authenticated can read visible photo drops" on public.photo_drops;
drop policy if exists "users can read own hidden photo drops" on public.photo_drops;
drop policy if exists "staff can read hidden photo drops" on public.photo_drops;
drop policy if exists "staff can moderate photo drops" on public.photo_drops;
create policy "anon and authenticated can read visible photo drops" on public.photo_drops
  for select to anon, authenticated using (
    hidden_by_dislikes is not true
    and hidden_by_moderator is not true
  );
create policy "users can read own hidden photo drops" on public.photo_drops
  for select to authenticated using (auth.uid() = user_id);
create policy "staff can read hidden photo drops" on public.photo_drops
  for select to authenticated using (public.can_manage_photos());
