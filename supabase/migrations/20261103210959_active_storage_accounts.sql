create or replace function private.active_actor() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and suspended_at is null);
$$;
revoke all on function private.active_actor() from public,anon;
grant execute on function private.active_actor() to authenticated;
drop policy post_media_insert on storage.objects;
create policy post_media_insert on storage.objects for insert to authenticated with check(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text and private.active_actor());
drop policy restaurant_media_insert on storage.objects;
create policy restaurant_media_insert on storage.objects for insert to authenticated with check(bucket_id='restaurant-media' and (storage.foldername(name))[1]=auth.uid()::text and private.active_actor());
drop policy post_media_update on storage.objects;
create policy post_media_update on storage.objects for update to authenticated using(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text and private.active_actor()) with check(bucket_id='post-media' and (storage.foldername(name))[1]=auth.uid()::text and private.active_actor());
