-- News/announcements are global across all of CruiseCrew. They are not scoped
-- by group_id or crew_id, so RLS should not require any crew/group membership.
alter table public.announcements enable row level security;

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
