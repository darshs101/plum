-- Public-account follows can be approved immediately. Private follows cannot bypass approval.
create or replace function private.public_follow_target(subject uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=subject and visibility='public' and suspended_at is null);
$$;
revoke all on function private.public_follow_target(uuid) from public,anon;
grant execute on function private.public_follow_target(uuid) to authenticated;
drop policy follow_create on public.follows;
create policy follow_create on public.follows for insert to authenticated with check(follower_id=(select auth.uid()) and follower_id<>following_id and (status='requested' or private.public_follow_target(following_id)));
drop policy follow_read on public.follows;
create policy follow_read on public.follows for select to authenticated using(follower_id=(select auth.uid()) or following_id=(select auth.uid()) or (status='approved' and private.can_view_profile(follower_id) and private.can_view_profile(following_id)));
-- Immutable identity/admin columns cannot be changed through an otherwise legitimate row update.
revoke update on public.follows from authenticated;
grant update(status,approved_at) on public.follows to authenticated;
revoke update on public.profiles from authenticated;
grant update(username,display_name,visibility,avatar_path,city,neighborhood,onboarding_completed_at,updated_at) on public.profiles to authenticated;
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;
revoke insert,update on public.collections from authenticated;
grant insert(owner_id,title,kind,is_public) on public.collections to authenticated;
grant update(title,kind,is_public) on public.collections to authenticated;

-- Keep the stable application identity in sync with provider identities, without copying email.
create or replace function private.sync_auth_identity() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.provider in ('email','apple','google') then
  insert into public.auth_identities(user_id,provider,provider_subject) values(new.user_id,new.provider,new.provider_id)
  on conflict(provider,provider_subject) do nothing;
 end if;
 return new;
end $$;
revoke all on function private.sync_auth_identity() from public,anon,authenticated;
create trigger plum_auth_identity_created after insert on auth.identities for each row execute function private.sync_auth_identity();
insert into public.auth_identities(user_id,provider,provider_subject)
 select user_id,provider,provider_id from auth.identities where provider in ('email','apple','google')
 on conflict(provider,provider_subject) do nothing;

-- Realtime carries only rows that the subscriber can read through RLS.
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then alter publication supabase_realtime add table public.messages; end if;
end $$;
