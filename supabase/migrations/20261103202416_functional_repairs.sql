-- Predicate helpers are used by authenticated RLS policies, not exposed as RPCs.
grant usage on schema private to authenticated;
grant execute on function private.is_admin(), private.can_view_profile(uuid), private.can_view_post(uuid), private.is_mutual(uuid), private.can_read_post_media(text) to authenticated;

create or replace function private.is_conversation_member(subject uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.conversation_members m where m.conversation_id=subject and m.user_id=(select auth.uid()));
$$;
revoke all on function private.is_conversation_member(uuid) from public, anon;
grant execute on function private.is_conversation_member(uuid) to authenticated;
drop policy member_read on public.conversation_members;
create policy member_read on public.conversation_members for select to authenticated using(private.is_conversation_member(conversation_id));
drop policy conversation_read on public.conversations;
create policy conversation_read on public.conversations for select to authenticated using(private.is_conversation_member(id));
drop policy message_read on public.messages;
create policy message_read on public.messages for select to authenticated using(private.is_conversation_member(conversation_id));
drop policy message_add on public.messages;
create policy message_add on public.messages for insert to authenticated with check(sender_id=(select auth.uid()) and private.is_conversation_member(conversation_id));
create policy share_add on public.post_shares for insert to authenticated with check(private.can_view_post(post_id) and exists(select 1 from public.messages m where m.id=message_id and m.sender_id=(select auth.uid())));
create policy post_media_delete on storage.objects for delete to authenticated using(bucket_id='post-media' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy restaurant_media_delete on storage.objects for delete to authenticated using(bucket_id='restaurant-media' and (storage.foldername(name))[1]=(select auth.uid()::text));

-- All post changes commit together; invalid drafts leave the previous post intact.
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
  insert into public.post_photos(post_id,storage_path,position) values(post_uuid,path,idx); idx:=idx+1;
 end loop;
 perform public.validate_post(post_uuid);
 return post_uuid;
end $$;
revoke all on function public.save_post(uuid,uuid,jsonb,jsonb,text,date) from public,anon;
grant execute on function public.save_post(uuid,uuid,jsonb,jsonb,text,date) to authenticated;
