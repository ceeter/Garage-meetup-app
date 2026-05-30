-- Add optional MVP map fields for global meet pins.
alter table public.meets
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_label text;

comment on column public.meets.latitude is 'Optional meet latitude for CruiseCrew map pins.';
comment on column public.meets.longitude is 'Optional meet longitude for CruiseCrew map pins.';
comment on column public.meets.location_label is 'Optional map-friendly meet spot/address label.';
