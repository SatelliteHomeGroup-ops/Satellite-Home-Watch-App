create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  incoming_role text;
  normalized_role text;
  meta_first_name text;
  meta_last_name text;
  meta_full_name text;
  meta_phone text;
  meta_property_id uuid;
begin
  incoming_role := lower(trim(coalesce(new.raw_user_meta_data ->> 'role', '')));

  if incoming_role in ('corporate', 'manager', 'inspector', 'customer') then
    normalized_role := incoming_role;
  else
    normalized_role := 'customer';
  end if;

  meta_first_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'first_name', '')), '');
  meta_last_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'last_name', '')), '');
  meta_phone := nullif(trim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '');

  meta_full_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), '');
  if meta_full_name is null then
    meta_full_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'name', '')), '');
  end if;
  if meta_full_name is null then
    meta_full_name := nullif(trim(concat_ws(' ', meta_first_name, meta_last_name)), '');
  end if;

  meta_property_id := nullif(new.raw_user_meta_data ->> 'property_id', '')::uuid;

  insert into public.profiles (
    id,
    role,
    first_name,
    last_name,
    full_name,
    phone
  )
  values (
    new.id,
    normalized_role,
    meta_first_name,
    meta_last_name,
    meta_full_name,
    meta_phone
  )
  on conflict (id) do nothing;

  if normalized_role = 'customer' and meta_property_id is not null then
    insert into public.property_customers (
      property_id,
      customer_id,
      is_primary
    )
    values (
      meta_property_id,
      new.id,
      false
    )
    on conflict do nothing;
  end if;

  return new;
end;
$$;