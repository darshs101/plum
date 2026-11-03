-- Trigger functions are implementation details and must not be RPC endpoints.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.enforce_post_dish_restaurant() from public, anon, authenticated;
revoke all on function public.queue_notification() from public, anon, authenticated;
revoke all on function public.enforce_message_membership() from public, anon, authenticated;
revoke all on function public.create_social_notification() from public, anon, authenticated;
revoke all on function public.merge_dish(uuid, uuid) from public, anon, authenticated;
revoke all on function public.merge_restaurant(uuid, uuid) from public, anon, authenticated;

revoke all on table public.notification_outbox from anon, authenticated;
create policy notification_outbox_no_client_access on public.notification_outbox
  for select to authenticated using (false);
