create or replace function public.can_manage_invite_role(target_role text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when public.current_profile_role() = 'corporate' then
      target_role in ('corporate', 'manager', 'inspector', 'customer')
    when public.current_profile_role() = 'manager' then
      target_role = 'customer'
    else
      false
  end;
$$;

alter table public.invitations enable row level security;
alter table public.invitation_properties enable row level security;

do $$
declare
  pol record;
begin
  for pol in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('invitations', 'invitation_properties')
  loop
    execute format('drop policy if exists %I on %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  end loop;
end
$$;

-- invitations
create policy invitations_corporate_all on public.invitations
for all to authenticated
using (public.current_profile_role() = 'corporate')
with check (public.current_profile_role() = 'corporate');

create policy invitations_manager_select on public.invitations
for select to authenticated
using (public.current_profile_role() = 'manager');

create policy invitations_manager_insert_customer_only on public.invitations
for insert to authenticated
with check (
  public.current_profile_role() = 'manager'
  and role = 'customer'
);

create policy invitations_manager_update_customer_only on public.invitations
for update to authenticated
using (
  public.current_profile_role() = 'manager'
  and role = 'customer'
)
with check (
  public.current_profile_role() = 'manager'
  and role = 'customer'
);

-- invitation_properties
create policy invitation_properties_corporate_all on public.invitation_properties
for all to authenticated
using (public.current_profile_role() = 'corporate')
with check (public.current_profile_role() = 'corporate');

create policy invitation_properties_manager_select on public.invitation_properties
for select to authenticated
using (
  public.current_profile_role() = 'manager'
  and exists (
    select 1
    from public.invitations i
    where i.id = invitation_properties.invitation_id
      and i.role = 'customer'
  )
);

create policy invitation_properties_manager_insert_customer_only on public.invitation_properties
for insert to authenticated
with check (
  public.current_profile_role() = 'manager'
  and exists (
    select 1
    from public.invitations i
    where i.id = invitation_properties.invitation_id
      and i.role = 'customer'
  )
);

create policy invitation_properties_manager_update_customer_only on public.invitation_properties
for update to authenticated
using (
  public.current_profile_role() = 'manager'
  and exists (
    select 1
    from public.invitations i
    where i.id = invitation_properties.invitation_id
      and i.role = 'customer'
  )
)
with check (
  public.current_profile_role() = 'manager'
  and exists (
    select 1
    from public.invitations i
    where i.id = invitation_properties.invitation_id
      and i.role = 'customer'
  )
);