-- Store normalized address geocoding metadata for meet map pins.
alter table public.meets
  add column if not exists geocoded_address text,
  add column if not exists geocode_provider text,
  add column if not exists place_id text;

comment on column public.meets.geocoded_address is 'Formatted address returned by the meet geocoding provider.';
comment on column public.meets.geocode_provider is 'Provider used to geocode this meet location, for example geoapify.';
comment on column public.meets.place_id is 'Provider place identifier for the geocoded meet location, when available.';
