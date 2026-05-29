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
