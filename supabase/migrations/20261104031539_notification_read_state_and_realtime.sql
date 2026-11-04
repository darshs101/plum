-- Clear the signed-in recipient's unread notifications using server time.
create function public.mark_notifications_viewed() returns void
language sql security invoker set search_path='' as $$
 update public.notifications set read_at=now()
 where recipient_id=(select auth.uid()) and read_at is null;
$$;
revoke all on function public.mark_notifications_viewed() from public,anon;
grant execute on function public.mark_notifications_viewed() to authenticated;
create index notifications_unread_recipient_idx on public.notifications(recipient_id) where read_at is null;
-- Postgres Changes applies notification_own RLS to each subscriber.
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
  alter publication supabase_realtime add table public.notifications;
 end if;
end $$;
