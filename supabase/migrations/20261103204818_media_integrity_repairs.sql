alter table public.post_photos add column is_removed boolean not null default false;
drop policy post_photo_read on public.post_photos;
create policy post_photo_read on public.post_photos for select to authenticated using(not is_removed and private.can_view_post(post_id));
-- Owners manage uploads; visitors can sign only actual, eligible post photo objects.
create or replace function private.can_read_post_media(object_name text) returns boolean language sql stable security definer set search_path = '' as $$
 select (storage.foldername(object_name))[1]=auth.uid()::text or exists(select 1 from public.post_photos photo where not photo.is_removed and (object_name=photo.storage_path or object_name=photo.storage_path||'.original') and private.can_view_post(photo.post_id));
$$;
create or replace function private.check_post_complete() returns trigger language plpgsql security invoker set search_path = '' as $$
declare post_uuid uuid; row_value jsonb;
begin
 row_value:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 post_uuid:=case when tg_table_name='posts' then (row_value->>'id')::uuid else (row_value->>'post_id')::uuid end;
 if exists(select 1 from public.posts where id=post_uuid and not is_removed) and
 (not exists(select 1 from public.post_dishes where post_id=post_uuid) or not exists(select 1 from public.post_photos where post_id=post_uuid and not is_removed)) then raise exception 'A published tasting needs at least one dish rating and one photo'; end if;
 return null;
end $$;
revoke all on function private.check_post_complete() from public,anon,authenticated;
create constraint trigger post_complete after insert or update on public.posts deferrable initially deferred for each row execute function private.check_post_complete();
create constraint trigger post_dishes_complete after insert or update or delete on public.post_dishes deferrable initially deferred for each row execute function private.check_post_complete();
create constraint trigger post_photos_complete after insert or update or delete on public.post_photos deferrable initially deferred for each row execute function private.check_post_complete();

create or replace function public.moderate_report(report_uuid uuid, next_status public.report_status, remove_target boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare report public.reports; parent_post uuid;
begin
 if not private.is_admin() then raise exception 'Admin role required'; end if;
 select * into strict report from public.reports where id=report_uuid for update;
 if remove_target then
  case report.target_type
   when 'post' then update public.posts set is_removed=true where id=report.target_id;
   when 'photo' then
    update public.post_photos set is_removed=true where id=report.target_id returning post_id into parent_post;
    if parent_post is not null and not exists(select 1 from public.post_photos where post_id=parent_post and not is_removed) then update public.posts set is_removed=true where id=parent_post; end if;
   when 'account' then update public.profiles set suspended_at=now() where id=report.target_id;
   when 'restaurant' then update public.restaurants set is_removed=true where id=report.target_id;
   when 'dish' then update public.dishes set is_removed=true where id=report.target_id;
  end case;
 end if;
 update public.reports set status=next_status where id=report_uuid;
 insert into public.admin_actions(actor_id,action,target_type,target_id,metadata) values(auth.uid(),'moderate_report',report.target_type::text,report.target_id,jsonb_build_object('report_id',report_uuid,'status',next_status,'removed',remove_target));
end $$;
