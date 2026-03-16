-- USERS / PROFILES

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('corporate','manager','inspector','customer')),
  first_name text,
  last_name text,
  full_name text,
  phone text,
  avatar_url text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- PROPERTIES

create table properties (
  id uuid primary key default gen_random_uuid(),
  name text,
  street_1 text,
  street_2 text,
  city text,
  state text,
  zip_code text,
  country text,
  status text default 'active',
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- PROPERTY CUSTOMERS

create table property_customers (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references properties(id) on delete cascade,
  customer_id uuid references profiles(id) on delete cascade,
  is_primary boolean default false,
  created_at timestamptz default now()
);

-- INSPECTIONS / VISITS

create table inspections (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references properties(id) on delete cascade,
  assigned_inspector_id uuid references profiles(id),
  scheduled_for timestamptz,
  status text default 'scheduled',
  created_by uuid references profiles(id),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- REPORTS

create table reports (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid references inspections(id) on delete cascade,
  property_id uuid references properties(id),
  inspector_id uuid references profiles(id),
  title text,
  summary text,
  report_status text default 'draft',
  submitted_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- REPORT MEDIA

create table report_media (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references reports(id) on delete cascade,
  property_id uuid references properties(id),
  uploaded_by uuid references profiles(id),
  media_type text,
  file_path text,
  caption text,
  created_at timestamptz default now()
);

-- ALERTS

create table alerts (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references properties(id) on delete cascade,
  report_id uuid references reports(id),
  created_by uuid references profiles(id),
  title text,
  description text,
  severity text,
  status text default 'open',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- DOCUMENTS

create table documents (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references properties(id) on delete cascade,
  uploaded_by uuid references profiles(id),
  document_type text,
  title text,
  description text,
  file_path text,
  visible_to_customer boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- SERVICE REQUESTS

create table service_requests (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references properties(id) on delete cascade,
  customer_id uuid references profiles(id),
  title text,
  description text,
  status text default 'open',
  priority text default 'medium',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);