create table public.post_mentions(post_id uuid not null references public.posts(id) on delete cascade, mentioned_user_id uuid not null references public.profiles(id),primary key(post_id,mentioned_user_id));
alter table public.post_mentions enable row level security;
grant select on public.post_mentions to authenticated;
create policy post_mentions_read on public.post_mentions for select to authenticated using(private.can_view_post(post_id));
revoke insert,update,delete on public.comment_mentions from authenticated;
create or replace function private.sync_mentions() returns trigger language plpgsql security definer set search_path = '' as $$
declare mentioned uuid; handle text; text_value text;
begin
 text_value := case when tg_table_name='posts' then to_jsonb(new)->>'caption' else to_jsonb(new)->>'body' end;
 if tg_table_name='posts' then delete from public.post_mentions where post_id=new.id; end if;
 for handle in select distinct lower(m[1]) from regexp_matches(coalesce(text_value,''),'@([a-zA-Z0-9_]{3,30})','g') m loop
  select id into mentioned from public.profiles where username=handle and suspended_at is null;
  if mentioned is null or not private.is_mutual(mentioned) then raise exception 'You can mention only mutual followers: @%',handle; end if;
  if tg_table_name='posts' then insert into public.post_mentions values(new.id,mentioned) on conflict do nothing;
  else insert into public.comment_mentions values(new.id,mentioned) on conflict do nothing; end if;
 end loop;
 return new;
end $$;
revoke all on function private.sync_mentions() from public,anon,authenticated;
create trigger posts_sync_mentions after insert or update of caption on public.posts for each row execute function private.sync_mentions();
create trigger comments_sync_mentions after insert on public.comments for each row execute function private.sync_mentions();
create or replace function private.check_comment_parent() returns trigger language plpgsql security invoker set search_path = '' as $$
begin
 if new.parent_id is not null and not exists(select 1 from public.comments where id=new.parent_id and post_id=new.post_id) then raise exception 'Reply must belong to this post'; end if; return new;
end $$;
revoke all on function private.check_comment_parent() from public,anon,authenticated;
create trigger comment_parent_check before insert on public.comments for each row execute function private.check_comment_parent();
-- Replies notify the person being replied to, rather than always notifying the post owner.
create or replace function public.create_social_notification() returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid; kind_value public.notification_kind; comment_uuid uuid; actor uuid; post_uuid uuid;
begin
 actor:=coalesce((to_jsonb(new)->>'user_id')::uuid,(to_jsonb(new)->>'author_id')::uuid,(to_jsonb(new)->>'follower_id')::uuid);
 post_uuid:=(to_jsonb(new)->>'post_id')::uuid;
 if tg_table_name='likes' then select author_id into recipient from public.posts where id=post_uuid; kind_value:='like';
 elsif tg_table_name='comments' then
  if new.parent_id is null then select author_id into recipient from public.posts where id=post_uuid; kind_value:='comment';
  else select author_id into recipient from public.comments where id=new.parent_id; kind_value:='reply'; end if;
  comment_uuid:=new.id;
 else
  if tg_op='UPDATE' and (to_jsonb(new)->>'status')='approved' then recipient:=new.follower_id;actor:=new.following_id;kind_value:='follow_approval';
  else recipient:=new.following_id;kind_value:=case when new.status='requested' then 'follow_request'::public.notification_kind else 'follow'::public.notification_kind end; end if;
 end if;
 if recipient is not null and recipient<>actor then insert into public.notifications(recipient_id,actor_id,kind,post_id,comment_id) values(recipient,actor,kind_value,post_uuid,comment_uuid); end if;
 return new;
end $$;

create or replace function private.require_active_actor() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and suspended_at is not null) then raise exception 'This account is suspended'; end if;
 if tg_op='DELETE' then return old; end if; return new;
end $$;
revoke all on function private.require_active_actor() from public,anon,authenticated;
do $$ declare tab text; begin
 foreach tab in array array['profiles','posts','post_dishes','post_photos','restaurants','dishes','follows','likes','comments','collections','collection_items','messages','post_shares','reports','device_tokens'] loop
 execute format('create trigger require_active_actor before insert or update or delete on public.%I for each row execute function private.require_active_actor()',tab);
 end loop;
end $$;

create or replace function public.moderate_report(report_uuid uuid, next_status public.report_status, remove_target boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare report public.reports;
begin
 if not private.is_admin() then raise exception 'Admin role required'; end if;
 select * into strict report from public.reports where id=report_uuid for update;
 if remove_target then
  case report.target_type
   when 'post' then update public.posts set is_removed=true where id=report.target_id;
   when 'photo' then update public.posts set is_removed=true where id in(select post_id from public.post_photos where id=report.target_id);
   when 'account' then update public.profiles set suspended_at=now() where id=report.target_id;
   when 'restaurant' then update public.restaurants set is_removed=true where id=report.target_id;
   when 'dish' then update public.dishes set is_removed=true where id=report.target_id;
  end case;
 end if;
 update public.reports set status=next_status where id=report_uuid;
 insert into public.admin_actions(actor_id,action,target_type,target_id,metadata) values(auth.uid(),'moderate_report',report.target_type,report.target_id,jsonb_build_object('report_id',report_uuid,'status',next_status,'removed',remove_target));
end $$;
revoke all on function public.moderate_report(uuid,public.report_status,boolean) from public,anon;
grant execute on function public.moderate_report(uuid,public.report_status,boolean) to authenticated;
create or replace function public.admin_edit_directory(record_type text,record_uuid uuid,new_name text,new_address text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not private.is_admin() then raise exception 'Admin role required'; end if;
 if record_type='restaurant' then update public.restaurants set name=new_name,address=coalesce(new_address,address),updated_at=now() where id=record_uuid;
 elsif record_type='dish' then update public.dishes set name=new_name,updated_at=now() where id=record_uuid;
 else raise exception 'Invalid record type'; end if;
 insert into public.admin_actions(actor_id,action,target_type,target_id,metadata) values(auth.uid(),'edit',record_type,record_uuid,jsonb_build_object('name',new_name,'address',new_address));
end $$;
revoke all on function public.admin_edit_directory(text,uuid,text,text) from public,anon;
grant execute on function public.admin_edit_directory(text,uuid,text,text) to authenticated;
