alter table public.properties
  add column if not exists gate_codes text,
  add column if not exists community_name text,
  add column if not exists alarm_notes text,
  add column if not exists access_instructions text;

update public.properties
set country = 'USA'
where country is null or btrim(country) = '';

update public.properties
set status = 'active'
where status is null or btrim(status) = '';

alter table public.properties
  alter column name set not null,
  alter column street_1 set not null,
  alter column city set not null,
  alter column state set not null,
  alter column zip_code set not null,
  alter column country set default 'USA',
  alter column status set default 'active';

alter table public.properties
  drop constraint if exists properties_status_check;

alter table public.properties
  add constraint properties_status_check
  check (status in ('active', 'inactive'));