-- These RPCs verify the server-assigned admin claim before touching any record.
grant execute on function public.merge_dish(uuid,uuid),public.merge_restaurant(uuid,uuid) to authenticated;
