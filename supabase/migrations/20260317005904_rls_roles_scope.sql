-- RLS role-scoped access controls for core operational tables.
-- Roles come from public.profiles.role:
-- corporate, manager, inspector, customer

create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
  limit 1;
$$;

create or replace function public.is_corporate_or_manager()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_profile_role() in ('corporate', 'manager'), false);
$$;

create or replace function public.is_customer()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_profile_role() = 'customer', false);
$$;

create or replace function public.is_inspector()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_profile_role() = 'inspector', false);
$$;

create or replace function public.customer_has_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.property_customers pc
    where pc.property_id = p_property_id
      and pc.customer_id = auth.uid()
  );
$$;

create or replace function public.inspector_has_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.inspections i
    where i.property_id = p_property_id
      and i.assigned_inspector_id = auth.uid()
  );
$$;

create or replace function public.inspector_has_inspection(p_inspection_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.inspections i
    where i.id = p_inspection_id
      and i.assigned_inspector_id = auth.uid()
  );
$$;

alter table public.profiles enable row level security;
alter table public.properties enable row level security;
alter table public.property_customers enable row level security;
alter table public.inspections enable row level security;
alter table public.reports enable row level security;
alter table public.report_media enable row level security;
alter table public.alerts enable row level security;
alter table public.documents enable row level security;
alter table public.service_requests enable row level security;

do $$
declare
  pol record;
begin
  for pol in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'profiles',
        'properties',
        'property_customers',
        'inspections',
        'reports',
        'report_media',
        'alerts',
        'documents',
        'service_requests'
      )
  loop
    execute format('drop policy if exists %I on %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  end loop;
end
$$;

-- profiles
create policy profiles_corporate_manager_all on public.profiles
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy profiles_customer_read_own on public.profiles
for select to authenticated
using (public.is_customer() and id = auth.uid());

create policy profiles_inspector_read_own on public.profiles
for select to authenticated
using (public.is_inspector() and id = auth.uid());

-- properties
create policy properties_corporate_manager_all on public.properties
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy properties_customer_read_linked on public.properties
for select to authenticated
using (public.is_customer() and public.customer_has_property(id));

create policy properties_inspector_read_assigned on public.properties
for select to authenticated
using (public.is_inspector() and public.inspector_has_property(id));

-- property_customers
create policy property_customers_corporate_manager_all on public.property_customers
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy property_customers_customer_read_own_link on public.property_customers
for select to authenticated
using (public.is_customer() and customer_id = auth.uid());

-- inspections
create policy inspections_corporate_manager_all on public.inspections
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy inspections_customer_read_linked on public.inspections
for select to authenticated
using (public.is_customer() and public.customer_has_property(property_id));

create policy inspections_inspector_read_assigned on public.inspections
for select to authenticated
using (public.is_inspector() and assigned_inspector_id = auth.uid());

-- reports
create policy reports_corporate_manager_all on public.reports
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy reports_customer_read_linked_property on public.reports
for select to authenticated
using (
  public.is_customer()
  and exists (
    select 1
    from public.inspections i
    where i.id = reports.inspection_id
      and public.customer_has_property(i.property_id)
  )
);

create policy reports_inspector_read_assigned on public.reports
for select to authenticated
using (
  public.is_inspector()
  and public.inspector_has_inspection(inspection_id)
);

create policy reports_inspector_insert_assigned on public.reports
for insert to authenticated
with check (
  public.is_inspector()
  and inspector_id = auth.uid()
  and public.inspector_has_inspection(inspection_id)
);

create policy reports_inspector_update_assigned on public.reports
for update to authenticated
using (
  public.is_inspector()
  and public.inspector_has_inspection(inspection_id)
)
with check (
  public.is_inspector()
  and public.inspector_has_inspection(inspection_id)
);

-- report_media
create policy report_media_corporate_manager_all on public.report_media
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy report_media_customer_read_linked_property on public.report_media
for select to authenticated
using (
  public.is_customer()
  and exists (
    select 1
    from public.reports r
    join public.inspections i on i.id = r.inspection_id
    where r.id = report_media.report_id
      and public.customer_has_property(i.property_id)
  )
);

create policy report_media_inspector_read_assigned on public.report_media
for select to authenticated
using (
  public.is_inspector()
  and exists (
    select 1
    from public.reports r
    where r.id = report_media.report_id
      and public.inspector_has_inspection(r.inspection_id)
  )
);

create policy report_media_inspector_insert_assigned on public.report_media
for insert to authenticated
with check (
  public.is_inspector()
  and uploaded_by = auth.uid()
  and exists (
    select 1
    from public.reports r
    where r.id = report_media.report_id
      and public.inspector_has_inspection(r.inspection_id)
  )
);

create policy report_media_inspector_update_assigned on public.report_media
for update to authenticated
using (
  public.is_inspector()
  and exists (
    select 1
    from public.reports r
    where r.id = report_media.report_id
      and public.inspector_has_inspection(r.inspection_id)
  )
)
with check (
  public.is_inspector()
  and exists (
    select 1
    from public.reports r
    where r.id = report_media.report_id
      and public.inspector_has_inspection(r.inspection_id)
  )
);

-- alerts
create policy alerts_corporate_manager_all on public.alerts
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy alerts_customer_read_linked on public.alerts
for select to authenticated
using (public.is_customer() and public.customer_has_property(property_id));

create policy alerts_inspector_read_assigned on public.alerts
for select to authenticated
using (public.is_inspector() and public.inspector_has_property(property_id));

-- documents
create policy documents_corporate_manager_all on public.documents
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy documents_customer_read_linked on public.documents
for select to authenticated
using (
  public.is_customer()
  and visible_to_customer = true
  and public.customer_has_property(property_id)
);

create policy documents_inspector_read_assigned on public.documents
for select to authenticated
using (public.is_inspector() and public.inspector_has_property(property_id));

-- service_requests
create policy service_requests_corporate_manager_all on public.service_requests
for all to authenticated
using (public.is_corporate_or_manager())
with check (public.is_corporate_or_manager());

create policy service_requests_customer_read_linked on public.service_requests
for select to authenticated
using (public.is_customer() and public.customer_has_property(property_id));

create policy service_requests_customer_insert_linked on public.service_requests
for insert to authenticated
with check (
  public.is_customer()
  and customer_id = auth.uid()
  and public.customer_has_property(property_id)
);