create or replace function public.register_device_token(token_value text, permission_value text) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if (select auth.uid()) is null or not private.active_actor() then raise exception 'active authentication required'; end if;
 if token_value !~ '^[0-9A-Fa-f]+$' or length(token_value) not between 32 and 512 or length(token_value)%2<>0 then raise exception 'invalid APNs token'; end if;
 if permission_value not in ('not_determined','denied','authorized','provisional') then raise exception 'invalid notification permission status'; end if;
 insert into public.device_tokens(user_id,token,platform,permission_status,updated_at) values((select auth.uid()),lower(token_value),'ios',permission_value,now()) on conflict(token) do update set user_id=excluded.user_id,platform='ios',permission_status=excluded.permission_status,updated_at=now();
end $$;
