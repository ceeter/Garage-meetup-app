alter table public.check_ins add column if not exists latitude double precision;
alter table public.check_ins add column if not exists longitude double precision;
alter table public.check_ins add column if not exists geocoded_address text;
alter table public.check_ins add column if not exists geocode_provider text;
alter table public.check_ins add column if not exists place_id text;

comment on column public.check_ins.latitude is 'Optional manually geocoded Cruise Mode spot latitude.';
comment on column public.check_ins.longitude is 'Optional manually geocoded Cruise Mode spot longitude.';
comment on column public.check_ins.geocoded_address is 'Optional formatted address returned for the manually shared Cruise Mode spot.';
comment on column public.check_ins.geocode_provider is 'Optional geocoding provider used for the manually shared Cruise Mode spot.';
comment on column public.check_ins.place_id is 'Optional provider place identifier for the manually shared Cruise Mode spot.';
