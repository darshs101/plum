-- Extends the established save_post contract without changing its six-argument
-- callers. photo_links is `[ { "photo_path": "…", "dish_ids": ["uuid"] } ]`.
create or replace function public.save_post(post_uuid uuid, restaurant_uuid uuid, dish_entries jsonb, photo_paths jsonb, caption_text text, visited_on date, photo_links jsonb)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare entry jsonb; path text; link jsonb; dish_uuid uuid; idx integer:=0;
begin
 if auth.uid() is null then raise exception 'Sign in to post'; end if;
 if jsonb_typeof(dish_entries)<>'array' or jsonb_array_length(dish_entries)<1 or jsonb_typeof(photo_paths)<>'array' or jsonb_array_length(photo_paths)<1 then raise exception 'Choose a dish, rating and at least one photo'; end if;
 if photo_links is null then photo_links:='[]'::jsonb; end if;
 if jsonb_typeof(photo_links)<>'array' then raise exception 'photo links must be an array'; end if;
 if visited_on > current_date then raise exception 'Visit date cannot be in the future'; end if;
 if not exists(select 1 from public.restaurants where id=restaurant_uuid and not is_removed) then raise exception 'Restaurant unavailable'; end if;
 if exists(select 1 from public.posts where id=post_uuid and author_id<>auth.uid()) then raise exception 'Only the author can edit this post'; end if;
 insert into public.posts(id,author_id,restaurant_id,caption,visit_date) values(post_uuid,auth.uid(),restaurant_uuid,nullif(caption_text,''),visited_on)
 on conflict(id) do update set restaurant_id=excluded.restaurant_id,caption=excluded.caption,visit_date=excluded.visit_date,updated_at=now();
 delete from public.post_dishes where post_id=post_uuid;
 delete from public.post_photos where post_id=post_uuid;
 for entry in select value from jsonb_array_elements(dish_entries) loop
   dish_uuid:=(entry->>'dish_id')::uuid;
   if not exists(select 1 from public.dishes where id=dish_uuid and restaurant_id=restaurant_uuid and not is_removed) then raise exception 'Dish must belong to the selected restaurant'; end if;
   insert into public.post_dishes(post_id,dish_id,rating) values(post_uuid,dish_uuid,(entry->>'rating')::numeric);
 end loop;
 for path in select jsonb_array_elements_text(photo_paths) loop
   if split_part(path,'/',1)<>auth.uid()::text or split_part(path,'/',2)<>post_uuid::text then raise exception 'Photo does not belong to this post'; end if;
   if not exists(select 1 from storage.objects where bucket_id='post-media' and name=path) then raise exception 'Upload the photo before publishing'; end if;
   insert into public.post_photos(post_id,storage_path,position) values(post_uuid,path,idx); idx:=idx+1;
 end loop;
 for link in select value from jsonb_array_elements(photo_links) loop
   path:=link->>'photo_path';
   if not exists(select 1 from public.post_photos where post_id=post_uuid and storage_path=path) then raise exception 'Photo link references a photo outside this post'; end if;
   for dish_uuid in select jsonb_array_elements_text(coalesce(link->'dish_ids','[]'::jsonb))::uuid loop
     insert into public.photo_dish_links(photo_id,post_dish_id)
       select pp.id,pd.id from public.post_photos pp join public.post_dishes pd on pd.post_id=pp.post_id
       where pp.post_id=post_uuid and pp.storage_path=path and pd.dish_id=dish_uuid
       on conflict do nothing;
     if not found then raise exception 'Photo link references a dish outside this post'; end if;
   end loop;
 end loop;
 perform public.validate_post(post_uuid); return post_uuid;
end $$;

create or replace function public.save_post(post_uuid uuid, restaurant_uuid uuid, dish_entries jsonb, photo_paths jsonb, caption_text text default null, visited_on date default null)
returns uuid language sql security invoker set search_path = '' as $$ select public.save_post(post_uuid,restaurant_uuid,dish_entries,photo_paths,caption_text,visited_on,'[]'::jsonb) $$;
revoke all on function public.save_post(uuid,uuid,jsonb,jsonb,text,date,jsonb), public.save_post(uuid,uuid,jsonb,jsonb,text,date) from public,anon;
grant execute on function public.save_post(uuid,uuid,jsonb,jsonb,text,date,jsonb), public.save_post(uuid,uuid,jsonb,jsonb,text,date) to authenticated;

-- A private account must not be discoverable by this convenience RPC.
create or replace function public.profile_identity(subject uuid)
returns table(id uuid, username text, display_name text, visibility public.account_visibility, city text, neighborhood text)
language sql stable security definer set search_path = '' as $$
 select p.id,p.username,p.display_name,p.visibility,p.city,p.neighborhood
 from public.profiles p where p.id=subject and p.suspended_at is null and private.can_view_profile(p.id);
$$;
revoke all on function public.profile_identity(uuid) from public,anon;
grant execute on function public.profile_identity(uuid) to authenticated;

-- APNs device tokens are bearer-like, unguessable values. Possession permits moving
-- a token after local logout; direct table RLS still prevents client enumeration.
create or replace function public.register_device_token(token_value text, permission_value text) returns void
language plpgsql security definer set search_path = '' as $$
begin
 if (select auth.uid()) is null or not private.active_actor() then raise exception 'active authentication required'; end if;
 if token_value !~ '^[0-9A-Fa-f]+$' or length(token_value) not between 32 and 512 or length(token_value)%2<>0 then raise exception 'invalid APNs token'; end if;
 if permission_value not in ('not_determined','denied','authorized','provisional') then raise exception 'invalid notification permission status'; end if;
 insert into public.device_tokens(user_id,token,platform,permission_status,updated_at) values((select auth.uid()),lower(token_value),'ios',permission_value,now())
 on conflict(token) do update set user_id=excluded.user_id,platform='ios',permission_status=excluded.permission_status,updated_at=now();
end $$;
create or replace function public.unregister_device_token(token_value text) returns void
language plpgsql security definer set search_path = '' as $$ begin
 if (select auth.uid()) is null then raise exception 'authentication required'; end if;
 delete from public.device_tokens where token=lower(token_value) and user_id=(select auth.uid());
end $$;
revoke all on function public.register_device_token(text,text),public.unregister_device_token(text) from public,anon;
grant execute on function public.register_device_token(text,text),public.unregister_device_token(text) to authenticated;
