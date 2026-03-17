create table public.invitations (
  id uuid primary key default gen_random_uuid(),

  email text not null,
  first_name text,
  last_name text,

  role text not null
    check (role in ('corporate','manager','inspector','customer')),

  status text not null default 'pending'
    check (status in ('pending','accepted','expired','revoked')),

  invited_by uuid not null
    references public.profiles(id) on delete set null,

  accepted_user_id uuid
    references public.profiles(id) on delete set null,

  sent_at timestamptz not null default now(),
  expires_at timestamptz,
  accepted_at timestamptz,
  revoked_at timestamptz,

  notes text
);


create table public.invitation_properties (
  id uuid primary key default gen_random_uuid(),

  invitation_id uuid not null
    references public.invitations(id) on delete cascade,

  property_id uuid not null
    references public.properties(id) on delete cascade
);


alter table public.invitations enable row level security;
alter table public.invitation_properties enable row level security;