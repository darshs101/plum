-- A direct profile link may reveal only the identity needed to request a private follow.
-- Private content, location, counts, and collections remain protected by their existing policies.
create or replace function public.profile_identity(subject uuid)
returns table(id uuid,username text,display_name text,visibility public.account_visibility,city text,neighborhood text)
language sql stable security definer set search_path = '' as $$
 select p.id,p.username,p.display_name,p.visibility,
 case when private.can_view_profile(p.id) then p.city else null end,
 case when private.can_view_profile(p.id) then p.neighborhood else null end
 from public.profiles p where p.id=subject and p.suspended_at is null and auth.uid() is not null;
$$;
revoke all on function public.profile_identity(uuid) from public,anon;
grant execute on function public.profile_identity(uuid) to authenticated;
create or replace function public.reorder_collection(collection_uuid uuid, ordered_items uuid[])
returns void language plpgsql security invoker set search_path = '' as $$
begin
 if not exists(select 1 from public.collections where id=collection_uuid and owner_id=auth.uid() and kind='ranked') then raise exception 'Only the owner can rank this collection'; end if;
 perform 1 from public.collections where id=collection_uuid for update;
 if (select count(*) from public.collection_items where collection_id=collection_uuid)<>cardinality(ordered_items) or
 (select count(distinct x) from unnest(ordered_items) x)<>cardinality(ordered_items) or
 exists(select 1 from unnest(ordered_items) x where not exists(select 1 from public.collection_items where id=x and collection_id=collection_uuid)) then raise exception 'The collection changed. Reload and try again'; end if;
 update public.collection_items i set rank=o.position from unnest(ordered_items) with ordinality o(id,position) where i.id=o.id and i.collection_id=collection_uuid;
end $$;
revoke all on function public.reorder_collection(uuid,uuid[]) from public,anon;
grant execute on function public.reorder_collection(uuid,uuid[]) to authenticated;
create or replace function public.search_public(search_text text, cuisine_filter text default null, neighborhood_filter text default null, price_filter smallint default null)
returns table(kind text,id uuid,label text,subtitle text,score real)
language sql stable security invoker set search_path = public,extensions as $$
 with q as (select lower(trim(search_text)) needle), places as (
 select r.* from public.restaurants r where not r.is_removed
 and (cuisine_filter is null or lower(r.cuisine)=lower(cuisine_filter))
 and (neighborhood_filter is null or lower(r.neighborhood)=lower(neighborhood_filter))
 and (price_filter is null or r.price_level=price_filter)
 ), results as (
 select 'restaurant'::text kind,r.id,r.name label,coalesce(r.neighborhood,r.address) subtitle,
 case when lower(r.name)=q.needle then 100::real else similarity(lower(r.name),q.needle) end score
 from places r,q where q.needle='' or lower(r.name) like '%'||q.needle||'%' or lower(r.name)%q.needle or exists(select 1 from public.restaurant_aliases a where a.restaurant_id=r.id and (a.normalized_alias like '%'||q.needle||'%' or a.normalized_alias%q.needle))
 union all
 select 'dish',d.id,d.name,r.name,case when lower(d.name)=q.needle then 100::real else similarity(lower(d.name),q.needle) end
 from public.dishes d join places r on r.id=d.restaurant_id,q where not d.is_removed and (q.needle='' or lower(d.name) like '%'||q.needle||'%' or lower(d.name)%q.needle or exists(select 1 from public.dish_aliases a where a.dish_id=d.id and (a.normalized_alias like '%'||q.needle||'%' or a.normalized_alias%q.needle)))
 union all
 select 'user',p.id,p.username,p.display_name,case when lower(p.username)=q.needle then 100::real else similarity(lower(p.username),q.needle) end
 from public.profiles p,q where p.visibility='public' and p.suspended_at is null and (lower(p.username) like '%'||q.needle||'%' or lower(p.username)%q.needle) and cuisine_filter is null and neighborhood_filter is null and price_filter is null
 union all
 select 'collection',c.id,c.title,p.username,case when lower(c.title)=q.needle then 100::real else similarity(lower(c.title),q.needle) end
 from public.collections c join public.profiles p on p.id=c.owner_id,q where c.is_public and p.visibility='public' and p.suspended_at is null and (lower(c.title) like '%'||q.needle||'%' or lower(c.title)%q.needle) and cuisine_filter is null and neighborhood_filter is null and price_filter is null
 ) select * from results order by score desc,label limit 60;
$$;
