-- Add persistent one-per-user likes/dislikes for photo drops.

alter table public.photo_drops add column if not exists like_count integer not null default 0;
alter table public.photo_drops add column if not exists dislike_count integer not null default 0;
alter table public.photo_drops add column if not exists hidden_by_dislikes boolean not null default false;
alter table public.photo_drops add column if not exists hidden_at timestamptz;

create table if not exists public.photo_reactions (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.photo_drops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('like', 'dislike')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(photo_id, user_id)
);

create index if not exists photo_reactions_photo_id_idx on public.photo_reactions(photo_id);
create index if not exists photo_reactions_user_id_idx on public.photo_reactions(user_id);

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

-- Backfill counts from any existing reaction rows if this migration is rerun after data import.
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

-- Hidden photos remain in the database/storage, but are removed from the public feed.
drop policy if exists "anon and authenticated can read photo drops" on public.photo_drops;
create policy "anon and authenticated can read photo drops" on public.photo_drops
  for select to anon, authenticated using (
    hidden_by_dislikes is not true
    or auth.uid() = user_id
    or public.is_admin_user()
  );
