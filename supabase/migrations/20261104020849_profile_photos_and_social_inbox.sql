-- Private profile photos; originals are never made public by a bucket setting.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-media','profile-media',false,5242880,array['image/jpeg'])
on conflict(id) do nothing;
create policy profile_media_read on storage.objects for select to authenticated using (
 bucket_id='profile-media' and private.active_actor() and (
 (storage.foldername(name))[1]=(select auth.uid()::text) or exists(
 select 1 from public.profiles p where p.avatar_path=name and private.can_view_profile(p.id))));
create policy profile_media_insert on storage.objects for insert to authenticated with check(
 bucket_id='profile-media' and (storage.foldername(name))[1]=(select auth.uid()::text) and private.active_actor());
create policy profile_media_delete on storage.objects for delete to authenticated using(
 bucket_id='profile-media' and (storage.foldername(name))[1]=(select auth.uid()::text));

create function private.validate_profile_avatar() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.avatar_path is not distinct from old.avatar_path or new.avatar_path is null then return new; end if;
 if split_part(new.avatar_path,'/',1)<>new.id::text or not exists(
 select 1 from storage.objects where bucket_id='profile-media' and name=new.avatar_path) then
 raise exception 'Upload your profile photo before saving it'; end if;
 return new;
end $$;
revoke all on function private.validate_profile_avatar() from public,anon,authenticated;
create trigger validate_profile_avatar before update of avatar_path on public.profiles for each row execute function private.validate_profile_avatar();

-- Only mutual approved friends appear, including friends with no conversation.
-- Invoker security preserves all existing profile/message membership RLS.
create function public.friends_inbox()
returns table(id uuid,username text,display_name text,avatar_path text,last_message text,last_message_at timestamptz,followed_at timestamptz)
language sql stable security invoker set search_path='' as $$
 select p.id,p.username,p.display_name,p.avatar_path,last_message.body,last_message.created_at,
 greatest(coalesce(a.approved_at,a.created_at),coalesce(b.approved_at,b.created_at)) as followed_at
 from public.follows a join public.follows b on b.follower_id=a.following_id and b.following_id=a.follower_id and b.status='approved'
 join public.profiles p on p.id=a.following_id
 left join public.conversations c on c.direct_key=least(a.follower_id::text,a.following_id::text)||':'||greatest(a.follower_id::text,a.following_id::text)
 left join lateral(select m.body,m.created_at from public.messages m where m.conversation_id=c.id order by m.created_at desc,m.id desc limit 1) last_message on true
 where a.follower_id=(select auth.uid()) and a.status='approved' and p.suspended_at is null
 order by last_message.created_at desc nulls last, followed_at desc,p.id;
$$;
revoke all on function public.friends_inbox() from public,anon;
grant execute on function public.friends_inbox() to authenticated;

-- A request recipient needs the actor's identity to decide whether to approve.
-- This discloses no private activity or location, and no private avatar to a stranger.
create function public.notification_actor_profiles()
returns table(id uuid,username text,display_name text,visibility public.account_visibility,city text,neighborhood text,avatar_path text)
language sql stable security definer set search_path='' as $$
 select p.id,p.username,p.display_name,p.visibility,null::text,null::text,
 case when private.can_view_profile(p.id) then p.avatar_path else null end
 from public.profiles p where private.active_actor() and p.suspended_at is null and exists(
 select 1 from public.notifications n where n.recipient_id=(select auth.uid()) and n.actor_id=p.id);
$$;
revoke all on function public.notification_actor_profiles() from public,anon;
grant execute on function public.notification_actor_profiles() to authenticated;
