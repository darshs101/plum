create or replace function private.can_view_profile(subject uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select subject=auth.uid() or exists(select 1 from public.profiles p where p.id=subject and p.suspended_at is null and (p.visibility='public' or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.following_id=subject and f.status='approved')));
$$;
create or replace function public.merge_dish(source_dish uuid,target_dish uuid) returns void language plpgsql security definer set search_path = '' as $$
declare collapsed jsonb;
begin
 if not private.is_admin() or source_dish=target_dish then raise exception 'Admin role and distinct records required'; end if;
 if not exists(select 1 from public.dishes a join public.dishes b on b.restaurant_id=a.restaurant_id where a.id=source_dish and b.id=target_dish and not a.is_removed and not b.is_removed) then raise exception 'Merge dishes within the same restaurant location'; end if;
 perform 1 from public.dishes where id in(source_dish,target_dish) order by id for update;
 select jsonb_agg(to_jsonb(s)) into collapsed from public.post_dishes s join public.post_dishes t on t.post_id=s.post_id and t.dish_id=target_dish where s.dish_id=source_dish;
 insert into public.photo_dish_links(photo_id,post_dish_id) select l.photo_id,t.id from public.photo_dish_links l join public.post_dishes s on s.id=l.post_dish_id join public.post_dishes t on t.post_id=s.post_id and t.dish_id=target_dish where s.dish_id=source_dish on conflict do nothing;
 delete from public.post_dishes s where s.dish_id=source_dish and exists(select 1 from public.post_dishes t where t.post_id=s.post_id and t.dish_id=target_dish);
 insert into public.dish_aliases(dish_id,alias) select target_dish,name from public.dishes where id=source_dish on conflict do nothing;
 insert into public.dish_aliases(dish_id,alias) select target_dish,alias from public.dish_aliases where dish_id=source_dish on conflict do nothing;
 update public.post_dishes set dish_id=target_dish where dish_id=source_dish;
 update public.dishes set is_removed=true where id=source_dish;
 insert into public.record_merge_history(actor_id,record_type,source_id,target_id) values(auth.uid(),'dish',source_dish,target_dish);
 insert into public.admin_actions(actor_id,action,target_type,target_id,metadata) values(auth.uid(),'merge','dish',target_dish,jsonb_build_object('source',source_dish,'cooccurring_source_ratings',collapsed));
end $$;
create or replace function public.merge_restaurant(source_restaurant uuid,target_restaurant uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
 if not private.is_admin() or source_restaurant=target_restaurant then raise exception 'Admin role and distinct records required'; end if;
 if (select count(*) from public.restaurants where id in(source_restaurant,target_restaurant) and not is_removed)<>2 then raise exception 'Both locations must exist'; end if;
 perform 1 from public.restaurants where id in(source_restaurant,target_restaurant) order by id for update;
 insert into public.restaurant_aliases(restaurant_id,alias) select target_restaurant,name from public.restaurants where id=source_restaurant on conflict do nothing;
 insert into public.restaurant_aliases(restaurant_id,alias) select target_restaurant,alias from public.restaurant_aliases where restaurant_id=source_restaurant on conflict do nothing;
 update public.posts set restaurant_id=target_restaurant where restaurant_id=source_restaurant;
 update public.dishes set restaurant_id=target_restaurant where restaurant_id=source_restaurant;
 delete from public.collection_items a where a.restaurant_id=source_restaurant and exists(select 1 from public.collection_items b where b.collection_id=a.collection_id and b.restaurant_id=target_restaurant);
 update public.collection_items set restaurant_id=target_restaurant where restaurant_id=source_restaurant;
 update public.restaurants set is_removed=true where id=source_restaurant;
 insert into public.record_merge_history(actor_id,record_type,source_id,target_id) values(auth.uid(),'restaurant',source_restaurant,target_restaurant);
 insert into public.admin_actions(actor_id,action,target_type,target_id,metadata) values(auth.uid(),'merge','restaurant',target_restaurant,jsonb_build_object('source',source_restaurant));
end $$;
create or replace function public.admin_set_suspension(subject uuid,suspend boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
 if not private.is_admin() then raise exception 'Admin role required'; end if;
 if subject=auth.uid() then raise exception 'Cannot suspend your own admin account'; end if;
 update public.profiles set suspended_at=case when suspend then now() else null end where id=subject;
 insert into public.admin_actions(actor_id,action,target_type,target_id) values(auth.uid(),case when suspend then 'suspend' else 'restore' end,'account',subject);
end $$;
revoke all on function public.admin_set_suspension(uuid,boolean) from public,anon;
grant execute on function public.admin_set_suspension(uuid,boolean) to authenticated;
