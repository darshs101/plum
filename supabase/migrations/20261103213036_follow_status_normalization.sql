-- A client may request a follow, but it cannot choose approval state. Public follows
-- approve immediately; private follows always begin requested and owners approve them.
create or replace function public.normalize_follow_status() returns trigger language plpgsql security definer set search_path = '' as $$
declare target_visibility public.account_visibility;
begin
 select visibility into target_visibility from public.profiles where id=new.following_id;
 if tg_op='INSERT' then
   new.status:=case when target_visibility='private' then 'requested'::public.follow_status else 'approved'::public.follow_status end;
   new.approved_at:=case when target_visibility='public' then now() else null end;
 elsif new.status='approved' then
   new.approved_at:=coalesce(new.approved_at,now());
 end if;
 return new;
end $$;
revoke all on function public.normalize_follow_status() from public,anon,authenticated;
drop trigger if exists follows_normalize on public.follows;
create trigger follows_normalize before insert or update on public.follows for each row execute procedure public.normalize_follow_status();
-- Repair the public edge just created before the trigger existed.
update public.follows f set status='approved',approved_at=coalesce(approved_at,now()) from public.profiles p where p.id=f.following_id and p.visibility='public' and f.status='requested';
