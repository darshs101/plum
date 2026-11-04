-- Atomic direct-message send and optional post share; existing RLS and triggers enforce membership and mutual follows.
create function public.send_message_with_share(conversation_id uuid, body text default null, post_id uuid default null)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare message_uuid uuid;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 if nullif(btrim(body),'') is null and post_id is null then raise exception 'Message or post required'; end if;
 insert into public.messages(conversation_id,sender_id,body)
 values(conversation_id,(select auth.uid()),coalesce(nullif(btrim(body),''),'Shared a tasting'))
 returning id into message_uuid;
 if post_id is not null then
  insert into public.post_shares(message_id,post_id) values(message_uuid,post_id);
 end if;
 return message_uuid;
end $$;
revoke all on function public.send_message_with_share(uuid,text,uuid) from public,anon;
grant execute on function public.send_message_with_share(uuid,text,uuid) to authenticated;
