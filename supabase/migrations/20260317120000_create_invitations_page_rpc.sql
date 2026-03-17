create or replace function public.get_invitations_page(
  page_number integer default 1,
  page_size integer default 25,
  status_filter text default null,
  role_filter text default null
)
returns table (
  id uuid,
  email text,
  first_name text,
  last_name text,
  role text,
  status text,
  sent_at timestamptz,
  expires_at timestamptz,
  accepted_at timestamptz,
  revoked_at timestamptz,
  notes text,
  invited_by uuid,
  accepted_user_id uuid,
  property_count bigint
)
language sql
security invoker
set search_path = public, pg_temp
as $$
  select
    i.id,
    i.email,
    i.first_name,
    i.last_name,
    i.role,
    i.status,
    i.sent_at,
    i.expires_at,
    i.accepted_at,
    i.revoked_at,
    i.notes,
    i.invited_by,
    i.accepted_user_id,
    count(ip.id) as property_count
  from public.invitations i
  left join public.invitation_properties ip
    on ip.invitation_id = i.id
  where
    (status_filter is null or i.status = status_filter)
    and (role_filter is null or i.role = role_filter)
  group by
    i.id,
    i.email,
    i.first_name,
    i.last_name,
    i.role,
    i.status,
    i.sent_at,
    i.expires_at,
    i.accepted_at,
    i.revoked_at,
    i.notes,
    i.invited_by,
    i.accepted_user_id
  order by i.sent_at desc
  limit greatest(page_size, 1)
  offset greatest(page_number - 1, 0) * greatest(page_size, 1);
$$;

grant execute on function public.get_invitations_page(integer, integer, text, text) to authenticated;
