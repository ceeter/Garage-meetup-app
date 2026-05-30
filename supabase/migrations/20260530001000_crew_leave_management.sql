-- Enforce safe self-leave behavior for crews without relying only on client checks.

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

grant execute on function public.can_leave_group(uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;

drop policy if exists "users can leave own group membership" on public.group_memberships;
create policy "users can leave own group membership" on public.group_memberships
  for delete to authenticated using (
    public.is_admin_user()
    or (auth.uid() = user_id and public.can_leave_group(group_id))
  );
