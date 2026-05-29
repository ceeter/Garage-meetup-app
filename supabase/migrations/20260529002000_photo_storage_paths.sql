-- Store Supabase Storage object paths for uploaded photo drops so objects can be cleaned up later.
alter table public.photo_drops add column if not exists storage_path text;
create index if not exists photo_drops_storage_path_idx on public.photo_drops(storage_path);
