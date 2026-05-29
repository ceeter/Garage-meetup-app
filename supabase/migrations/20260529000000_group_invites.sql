create extension if not exists pgcrypto;

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

alter table public.group_invites enable row level security;

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
