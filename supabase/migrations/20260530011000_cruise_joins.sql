create table if not exists public.cruise_joins (
  id uuid primary key default gen_random_uuid(),
  check_in_id uuid references public.check_ins(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(check_in_id, user_id)
);

create index if not exists cruise_joins_check_in_id_idx on public.cruise_joins(check_in_id);
create index if not exists cruise_joins_user_id_idx on public.cruise_joins(user_id);

alter table public.cruise_joins enable row level security;

drop policy if exists "authenticated can read cruise joins" on public.cruise_joins;
drop policy if exists "users can insert own cruise join" on public.cruise_joins;
drop policy if exists "users can delete own cruise join" on public.cruise_joins;

create policy "authenticated can read cruise joins" on public.cruise_joins
  for select to authenticated using (true);
create policy "users can insert own cruise join" on public.cruise_joins
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users can delete own cruise join" on public.cruise_joins
  for delete to authenticated using (auth.uid() = user_id);
