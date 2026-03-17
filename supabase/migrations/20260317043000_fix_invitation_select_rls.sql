-- Ensure invitation workspace queries can read required tables for admin roles.
-- Grants SELECT access via RLS to corporate + manager users only.

-- invitations: corporate + manager can read all rows.
drop policy if exists invitations_manager_select on public.invitations;
drop policy if exists invitations_corporate_manager_select on public.invitations;

create policy invitations_corporate_manager_select on public.invitations
for select to authenticated
using (public.current_profile_role() in ('corporate', 'manager'));

-- invitation_properties: corporate + manager can read all rows.
-- (manager read was previously limited to customer invitations only.)
drop policy if exists invitation_properties_manager_select on public.invitation_properties;
drop policy if exists invitation_properties_corporate_manager_select on public.invitation_properties;

create policy invitation_properties_corporate_manager_select on public.invitation_properties
for select to authenticated
using (public.current_profile_role() in ('corporate', 'manager'));

-- properties: ensure explicit SELECT policy for corporate + manager.
-- Existing FOR ALL policy may already allow this; this keeps SELECT behavior explicit.
drop policy if exists properties_corporate_manager_select on public.properties;

create policy properties_corporate_manager_select on public.properties
for select to authenticated
using (public.current_profile_role() in ('corporate', 'manager'));

-- Table-level privileges for authenticated users (RLS still enforces row access).
grant select on table public.invitations to authenticated;
grant select on table public.invitation_properties to authenticated;
grant select on table public.properties to authenticated;
