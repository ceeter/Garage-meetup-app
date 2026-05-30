alter table public.check_ins add column if not exists updated_at timestamp with time zone default now();

update public.check_ins
set updated_at = coalesce(updated_at, created_at, now())
where updated_at is null;

delete from public.check_ins a
using public.check_ins b
where a.user_id is not null
  and a.user_id = b.user_id
  and a.id <> b.id
  and (
    coalesce(a.ended_at is null, false),
    coalesce(a.expires_at, '-infinity'::timestamp with time zone),
    coalesce(a.updated_at, a.created_at, '-infinity'::timestamp with time zone),
    a.id
  ) < (
    coalesce(b.ended_at is null, false),
    coalesce(b.expires_at, '-infinity'::timestamp with time zone),
    coalesce(b.updated_at, b.created_at, '-infinity'::timestamp with time zone),
    b.id
  );

create unique index if not exists check_ins_user_id_key on public.check_ins(user_id);
