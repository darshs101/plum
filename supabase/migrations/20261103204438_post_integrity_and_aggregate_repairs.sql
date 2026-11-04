create or replace function public.save_post(post_uuid uuid, restaurant_uuid uuid, dish_entries jsonb, photo_paths jsonb, caption_text text default null, visited_on date default null)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare entry jsonb; path text; idx integer:=0;
begin
 if auth.uid() is null then raise exception 'Sign in to post'; end if;
 if jsonb_array_length(dish_entries)<1 or jsonb_array_length(photo_paths)<1 then raise exception 'Choose a dish, rating and at least one photo'; end if;
 if exists(select 1 from public.posts where id=post_uuid and author_id<>auth.uid()) then raise exception 'Only the author can edit this post'; end if;
 insert into public.posts(id,author_id,restaurant_id,caption,visit_date) values(post_uuid,auth.uid(),restaurant_uuid,caption_text,visited_on)
 on conflict(id) do update set restaurant_id=excluded.restaurant_id, caption=excluded.caption,visit_date=excluded.visit_date,updated_at=now();
 delete from public.post_dishes where post_id=post_uuid;
 delete from public.post_photos where post_id=post_uuid;
 for entry in select * from jsonb_array_elements(dish_entries) loop
  insert into public.post_dishes(post_id,dish_id,rating) values(post_uuid,(entry->>'dish_id')::uuid,(entry->>'rating')::numeric);
 end loop;
 for path in select jsonb_array_elements_text(photo_paths) loop
  if split_part(path,'/',1)<>auth.uid()::text or split_part(path,'/',2)<>post_uuid::text then raise exception 'Photo does not belong to this post'; end if;
  if not exists(select 1 from storage.objects where bucket_id='post-media' and name=path) then raise exception 'Upload the photo before publishing'; end if;
  insert into public.post_photos(post_id,storage_path,position) values(post_uuid,path,idx); idx:=idx+1;
 end loop;
 perform public.validate_post(post_uuid);
 return post_uuid;
end $$;
revoke all on function public.save_post(uuid,uuid,jsonb,jsonb,text,date) from public,anon;
grant execute on function public.save_post(uuid,uuid,jsonb,jsonb,text,date) to authenticated;

create or replace view public.public_restaurant_aggregates with(security_invoker=true) as
with latest as (
 select distinct on(p.author_id,pd.dish_id) p.author_id,p.restaurant_id,pd.dish_id,pd.rating
 from public.post_dishes pd join public.posts p on p.id=pd.post_id join public.profiles u on u.id=p.author_id
 join public.dishes d on d.id=pd.dish_id join public.restaurants r on r.id=p.restaurant_id
 where not p.is_removed and not d.is_removed and not r.is_removed and u.visibility='public' and u.suspended_at is null
 order by p.author_id,pd.dish_id,p.created_at desc
) select restaurant_id,avg(rating)::numeric(3,2) average_rating,count(*)::bigint rating_count from latest group by restaurant_id;
