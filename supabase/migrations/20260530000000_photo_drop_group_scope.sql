-- Add the crew scope column expected by the photo drop feed.
-- CruiseCrew stores crews in public.groups and references them with group_id.
alter table public.photo_drops
  add column if not exists group_id uuid references public.groups(id) on delete set null;

create index if not exists photo_drops_group_id_idx on public.photo_drops(group_id);
