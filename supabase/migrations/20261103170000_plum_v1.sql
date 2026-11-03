-- Plum v1. Additive initial schema. Apply with `supabase db push` only after linking
-- the intended project; this migration contains no secrets or destructive DDL.
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
create schema if not exists private;

create type public.account_visibility as enum ('public', 'private');
create type public.follow_status as enum ('requested', 'approved');
create type public.collection_kind as enum ('saved_places', 'standard', 'ranked');
create type public.notification_kind as enum ('like', 'comment', 'reply', 'follow', 'follow_request', 'follow_approval');
create type public.report_target as enum ('post', 'account', 'photo', 'restaurant', 'dish');
create type public.report_status as enum ('open', 'triaged', 'resolved', 'dismissed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,30}$'),
  display_name text not null check (char_length(display_name) between 1 and 80),
  visibility public.account_visibility not null default 'public', avatar_path text,
  city text default 'Atlanta', neighborhood text, onboarding_completed_at timestamptz,
  suspended_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.auth_identities (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider in ('email', 'apple', 'google')), provider_subject text not null,
  created_at timestamptz not null default now(), unique(provider, provider_subject)
);
create table public.device_tokens (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique, platform text not null check(platform = 'ios'), permission_status text not null check(permission_status in ('not_determined','denied','authorized','provisional')),
  updated_at timestamptz not null default now()
);
create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  status public.follow_status not null, created_at timestamptz not null default now(), approved_at timestamptz,
  primary key (follower_id, following_id), check (follower_id <> following_id)
);
create table public.restaurants (
  id uuid primary key default gen_random_uuid(), name text not null check(char_length(trim(name)) > 0),
  address text not null check(char_length(trim(address)) > 0), neighborhood text, cuisine text, price_level smallint check(price_level between 1 and 4),
  photo_path text not null, created_by uuid not null references public.profiles(id), is_removed boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.restaurant_aliases (restaurant_id uuid not null references public.restaurants(id) on delete cascade, alias text not null, normalized_alias text generated always as (lower(trim(alias))) stored, primary key(restaurant_id, normalized_alias));
create table public.dishes (
  id uuid primary key default gen_random_uuid(), restaurant_id uuid not null references public.restaurants(id), name text not null check(char_length(trim(name)) > 0),
  created_by uuid not null references public.profiles(id), is_removed boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.dish_aliases (dish_id uuid not null references public.dishes(id) on delete cascade, alias text not null, normalized_alias text generated always as (lower(trim(alias))) stored, primary key(dish_id, normalized_alias));
create table public.posts (
  id uuid primary key default gen_random_uuid(), author_id uuid not null references public.profiles(id), restaurant_id uuid not null references public.restaurants(id),
  caption text check(char_length(caption) <= 2200), visit_date date check(visit_date <= current_date), is_removed boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.post_dishes (
  id uuid primary key default gen_random_uuid(), post_id uuid not null references public.posts(id) on delete cascade, dish_id uuid not null references public.dishes(id),
  rating numeric(2,1) not null check(rating between 0.5 and 5.0 and mod((rating * 10)::integer, 5) = 0), created_at timestamptz not null default now(), unique(post_id, dish_id)
);
create table public.post_photos (id uuid primary key default gen_random_uuid(), post_id uuid not null references public.posts(id) on delete cascade, storage_path text not null unique, position smallint not null default 0 check(position >= 0), created_at timestamptz not null default now(), unique(post_id, position));
create table public.photo_dish_links (photo_id uuid not null references public.post_photos(id) on delete cascade, post_dish_id uuid not null references public.post_dishes(id) on delete cascade, primary key(photo_id, post_dish_id));
create table public.likes (post_id uuid not null references public.posts(id) on delete cascade, user_id uuid not null references public.profiles(id) on delete cascade, created_at timestamptz not null default now(), primary key(post_id,user_id));
create table public.comments (id uuid primary key default gen_random_uuid(), post_id uuid not null references public.posts(id) on delete cascade, author_id uuid not null references public.profiles(id), parent_id uuid references public.comments(id) on delete cascade, body text not null check(char_length(trim(body)) between 1 and 2200), created_at timestamptz not null default now());
create table public.comment_mentions (comment_id uuid not null references public.comments(id) on delete cascade, mentioned_user_id uuid not null references public.profiles(id), primary key(comment_id,mentioned_user_id));
create table public.collections (id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade, title text not null check(char_length(trim(title)) between 1 and 100), kind public.collection_kind not null default 'standard', is_public boolean not null default false, is_curated boolean not null default false, created_at timestamptz not null default now(), unique(owner_id,title));
create table public.collection_items (id uuid primary key default gen_random_uuid(), collection_id uuid not null references public.collections(id) on delete cascade, restaurant_id uuid references public.restaurants(id), post_id uuid references public.posts(id) on delete restrict, rank integer, created_at timestamptz not null default now(), check((restaurant_id is null) <> (post_id is null)), unique(collection_id,restaurant_id), unique(collection_id,post_id));
create table public.conversations (id uuid primary key default gen_random_uuid(), direct_key text not null unique, created_at timestamptz not null default now());
create table public.conversation_members (conversation_id uuid not null references public.conversations(id) on delete cascade, user_id uuid not null references public.profiles(id) on delete cascade, primary key(conversation_id,user_id));
create table public.messages (id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.conversations(id) on delete cascade, sender_id uuid not null references public.profiles(id), body text check(char_length(body) between 1 and 4000), created_at timestamptz not null default now());
create table public.post_shares (message_id uuid primary key references public.messages(id) on delete cascade, post_id uuid not null references public.posts(id) on delete restrict);
create table public.notifications (id uuid primary key default gen_random_uuid(), recipient_id uuid not null references public.profiles(id) on delete cascade, actor_id uuid references public.profiles(id), kind public.notification_kind not null, post_id uuid references public.posts(id) on delete cascade, comment_id uuid references public.comments(id) on delete cascade, read_at timestamptz, created_at timestamptz not null default now());
create table public.reports (id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id), target_type public.report_target not null, target_id uuid not null, reason text not null check(char_length(trim(reason)) between 1 and 1000), status public.report_status not null default 'open', created_at timestamptz not null default now());
create table public.admin_actions (id uuid primary key default gen_random_uuid(), actor_id uuid not null references public.profiles(id), action text not null, target_type text not null, target_id uuid, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create table public.record_merge_history (id uuid primary key default gen_random_uuid(), actor_id uuid not null references public.profiles(id), record_type text not null check(record_type in ('restaurant','dish')), source_id uuid not null, target_id uuid not null, created_at timestamptz not null default now(), check(source_id <> target_id));
create table public.notification_outbox (id uuid primary key default gen_random_uuid(), notification_id uuid not null references public.notifications(id) on delete cascade, created_at timestamptz not null default now(), delivered_at timestamptz);

create index follows_following_approved_idx on public.follows(following_id, status); create index follows_follower_approved_idx on public.follows(follower_id, status);
create index dishes_restaurant_idx on public.dishes(restaurant_id); create index posts_author_created_idx on public.posts(author_id, created_at desc) where not is_removed; create index posts_restaurant_idx on public.posts(restaurant_id, created_at desc) where not is_removed; create index post_dishes_dish_idx on public.post_dishes(dish_id, created_at desc); create index comments_post_idx on public.comments(post_id, created_at); create index collections_owner_idx on public.collections(owner_id); create index collection_items_collection_idx on public.collection_items(collection_id, rank); create index messages_conversation_idx on public.messages(conversation_id, created_at); create index notifications_recipient_idx on public.notifications(recipient_id, created_at desc); create index restaurants_name_trgm on public.restaurants using gin(name gin_trgm_ops); create index dishes_name_trgm on public.dishes using gin(name gin_trgm_ops);

create or replace function private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.suspended_at is null and coalesce((auth.jwt()->'app_metadata'->>'plum_role'),'')='admin') $$;
create or replace function private.can_view_profile(subject uuid) returns boolean language sql stable security definer set search_path = '' as $$ select subject=(select auth.uid()) or exists(select 1 from public.profiles p where p.id=subject and p.visibility='public' and p.suspended_at is null) or exists(select 1 from public.follows f where f.follower_id=(select auth.uid()) and f.following_id=subject and f.status='approved') $$;
create or replace function private.can_view_post(post_uuid uuid) returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.posts p where p.id=post_uuid and not p.is_removed and private.can_view_profile(p.author_id)) $$;
create or replace function private.is_mutual(other uuid) returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.follows a join public.follows b on b.follower_id=a.following_id and b.following_id=a.follower_id and b.status='approved' where a.follower_id=(select auth.uid()) and a.following_id=other and a.status='approved') $$;
revoke all on function private.is_admin(), private.can_view_profile(uuid), private.can_view_post(uuid), private.is_mutual(uuid) from public, anon, authenticated;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$ begin insert into public.profiles(id,username,display_name) values(new.id, lower(coalesce(new.raw_user_meta_data->>'username', 'plum_' || substr(new.id::text,1,8))), coalesce(new.raw_user_meta_data->>'display_name','Plum eater')); insert into public.collections(owner_id,title,kind,is_public) values(new.id,'Saved Places','saved_places',false); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.enforce_post_dish_restaurant() returns trigger language plpgsql security definer set search_path = '' as $$ begin if not exists(select 1 from public.posts p join public.dishes d on d.id=new.dish_id where p.id=new.post_id and p.restaurant_id=d.restaurant_id) then raise exception 'dish must belong to post restaurant'; end if; return new; end $$;
create trigger post_dish_restaurant before insert or update on public.post_dishes for each row execute procedure public.enforce_post_dish_restaurant();
create or replace function public.validate_post(post_uuid uuid) returns boolean language plpgsql security invoker set search_path = '' as $$ begin if not exists(select 1 from public.post_dishes where post_id=post_uuid) or not exists(select 1 from public.post_photos where post_id=post_uuid) then raise exception 'posts require one dish rating and one photo'; end if; return true; end $$;
create or replace function public.queue_notification() returns trigger language plpgsql security definer set search_path = '' as $$ begin insert into public.notification_outbox(notification_id) values(new.id); return new; end $$;
create trigger notification_outbox_trigger after insert on public.notifications for each row execute procedure public.queue_notification();

-- Public aggregates intentionally use only public-account, non-removed posts and latest rating per author/dish.
create view public.public_dish_aggregates with (security_invoker=true) as select pd.dish_id, avg(pd.rating)::numeric(3,2) average_rating, count(*) rating_count from (select distinct on (p.author_id,pd.dish_id) p.author_id,pd.dish_id,pd.rating from public.post_dishes pd join public.posts p on p.id=pd.post_id join public.profiles u on u.id=p.author_id where not p.is_removed and u.visibility='public' and u.suspended_at is null order by p.author_id,pd.dish_id,p.created_at desc) pd group by pd.dish_id;
create view public.public_restaurant_aggregates with (security_invoker=true) as select d.restaurant_id, avg(a.average_rating)::numeric(3,2) average_rating, sum(a.rating_count)::bigint rating_count from public.public_dish_aggregates a join public.dishes d on d.id=a.dish_id group by d.restaurant_id;

alter table public.profiles enable row level security; alter table public.auth_identities enable row level security; alter table public.device_tokens enable row level security; alter table public.follows enable row level security; alter table public.restaurants enable row level security; alter table public.restaurant_aliases enable row level security; alter table public.dishes enable row level security; alter table public.dish_aliases enable row level security; alter table public.posts enable row level security; alter table public.post_dishes enable row level security; alter table public.post_photos enable row level security; alter table public.photo_dish_links enable row level security; alter table public.likes enable row level security; alter table public.comments enable row level security; alter table public.comment_mentions enable row level security; alter table public.collections enable row level security; alter table public.collection_items enable row level security; alter table public.conversations enable row level security; alter table public.conversation_members enable row level security; alter table public.messages enable row level security; alter table public.post_shares enable row level security; alter table public.notifications enable row level security; alter table public.reports enable row level security; alter table public.admin_actions enable row level security; alter table public.record_merge_history enable row level security; alter table public.notification_outbox enable row level security;
revoke all on all tables in schema public from anon, authenticated; grant select,insert,update,delete on all tables in schema public to authenticated;

create policy profile_read on public.profiles for select to authenticated using (private.can_view_profile(id)); create policy profile_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy identity_own on public.auth_identities for select to authenticated using(user_id=(select auth.uid())); create policy token_own on public.device_tokens for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy follow_read on public.follows for select to authenticated using(follower_id=(select auth.uid()) or following_id=(select auth.uid()) or status='approved'); create policy follow_create on public.follows for insert to authenticated with check(follower_id=(select auth.uid()) and follower_id<>following_id); create policy follow_delete on public.follows for delete to authenticated using(follower_id=(select auth.uid()) or following_id=(select auth.uid())); create policy follow_update on public.follows for update to authenticated using(following_id=(select auth.uid())) with check(following_id=(select auth.uid()));
create policy restaurant_read on public.restaurants for select to authenticated using(not is_removed); create policy restaurant_add on public.restaurants for insert to authenticated with check(created_by=(select auth.uid())); create policy restaurant_admin on public.restaurants for update to authenticated using(private.is_admin()) with check(private.is_admin()); create policy restaurant_alias_read on public.restaurant_aliases for select to authenticated using(true);
create policy dish_read on public.dishes for select to authenticated using(not is_removed); create policy dish_add on public.dishes for insert to authenticated with check(created_by=(select auth.uid())); create policy dish_admin on public.dishes for update to authenticated using(private.is_admin()) with check(private.is_admin()); create policy dish_alias_read on public.dish_aliases for select to authenticated using(true);
create policy post_read on public.posts for select to authenticated using(private.can_view_post(id)); create policy post_write on public.posts for all to authenticated using(author_id=(select auth.uid())) with check(author_id=(select auth.uid())); create policy post_dish_read on public.post_dishes for select to authenticated using(private.can_view_post(post_id)); create policy post_dish_write on public.post_dishes for all to authenticated using(exists(select 1 from public.posts p where p.id=post_id and p.author_id=(select auth.uid()))) with check(exists(select 1 from public.posts p where p.id=post_id and p.author_id=(select auth.uid()))); create policy post_photo_read on public.post_photos for select to authenticated using(private.can_view_post(post_id)); create policy post_photo_write on public.post_photos for all to authenticated using(exists(select 1 from public.posts p where p.id=post_id and p.author_id=(select auth.uid()))) with check(exists(select 1 from public.posts p where p.id=post_id and p.author_id=(select auth.uid()))); create policy photo_link_read on public.photo_dish_links for select to authenticated using(exists(select 1 from public.post_photos x where x.id=photo_id and private.can_view_post(x.post_id))); create policy photo_link_write on public.photo_dish_links for all to authenticated using(exists(select 1 from public.post_photos x join public.posts p on p.id=x.post_id where x.id=photo_id and p.author_id=(select auth.uid()))) with check(exists(select 1 from public.post_photos x join public.posts p on p.id=x.post_id where x.id=photo_id and p.author_id=(select auth.uid())));
create policy like_read on public.likes for select to authenticated using(private.can_view_post(post_id)); create policy like_write on public.likes for all to authenticated using(user_id=(select auth.uid()) and private.can_view_post(post_id)) with check(user_id=(select auth.uid()) and private.can_view_post(post_id)); create policy comment_read on public.comments for select to authenticated using(private.can_view_post(post_id)); create policy comment_add on public.comments for insert to authenticated with check(author_id=(select auth.uid()) and private.can_view_post(post_id)); create policy comment_delete on public.comments for delete to authenticated using(author_id=(select auth.uid()) or exists(select 1 from public.posts p where p.id=post_id and p.author_id=(select auth.uid()))); create policy mention_read on public.comment_mentions for select to authenticated using(exists(select 1 from public.comments c where c.id=comment_id and private.can_view_post(c.post_id))); create policy mention_add on public.comment_mentions for insert to authenticated with check(private.is_mutual(mentioned_user_id));
create policy collection_read on public.collections for select to authenticated using(owner_id=(select auth.uid()) or is_public and private.can_view_profile(owner_id)); create policy collection_write on public.collections for all to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid())); create policy collection_item_read on public.collection_items for select to authenticated using(exists(select 1 from public.collections c where c.id=collection_id and (c.owner_id=(select auth.uid()) or c.is_public and private.can_view_profile(c.owner_id)))); create policy collection_item_write on public.collection_items for all to authenticated using(exists(select 1 from public.collections c where c.id=collection_id and c.owner_id=(select auth.uid()))) with check(exists(select 1 from public.collections c where c.id=collection_id and c.owner_id=(select auth.uid())));
create policy conversation_read on public.conversations for select to authenticated using(exists(select 1 from public.conversation_members m where m.conversation_id=id and m.user_id=(select auth.uid()))); create policy member_read on public.conversation_members for select to authenticated using(exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=(select auth.uid()))); create policy message_read on public.messages for select to authenticated using(exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=(select auth.uid()))); create policy message_add on public.messages for insert to authenticated with check(sender_id=(select auth.uid()) and exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=(select auth.uid()))); create policy share_read on public.post_shares for select to authenticated using(exists(select 1 from public.messages m where m.id=message_id and exists(select 1 from public.conversation_members cm where cm.conversation_id=m.conversation_id and cm.user_id=(select auth.uid()))));
create policy notification_own on public.notifications for select to authenticated using(recipient_id=(select auth.uid())); create policy notification_read_update on public.notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid())); create policy report_own on public.reports for select to authenticated using(reporter_id=(select auth.uid()) or private.is_admin()); create policy report_add on public.reports for insert to authenticated with check(reporter_id=(select auth.uid())); create policy report_admin on public.reports for update to authenticated using(private.is_admin()) with check(private.is_admin()); create policy admin_actions_admin on public.admin_actions for select to authenticated using(private.is_admin()); create policy merge_history_read on public.record_merge_history for select to authenticated using(true);

-- Storage: originals remain private; transformed delivery must use signed URLs after post visibility is checked.
insert into storage.buckets(id,name,public) values ('post-media','post-media',false),('restaurant-media','restaurant-media',false) on conflict(id) do nothing;
create policy post_media_select on storage.objects for select to authenticated using(bucket_id='post-media' and (storage.foldername(name))[1]=(select auth.uid()::text)); create policy post_media_insert on storage.objects for insert to authenticated with check(bucket_id='post-media' and (storage.foldername(name))[1]=(select auth.uid()::text)); create policy post_media_update on storage.objects for update to authenticated using(bucket_id='post-media' and (storage.foldername(name))[1]=(select auth.uid()::text)) with check(bucket_id='post-media' and (storage.foldername(name))[1]=(select auth.uid()::text)); create policy restaurant_media_insert on storage.objects for insert to authenticated with check(bucket_id='restaurant-media' and (storage.foldername(name))[1]=(select auth.uid()::text));

-- Server-side actions keep pair membership and notification recipients accountable.
create or replace function public.start_direct_conversation(other_user uuid) returns uuid language plpgsql security definer set search_path = '' as $$
declare conversation_uuid uuid; key text;
begin
  if not private.is_mutual(other_user) then raise exception 'direct messages require mutual approved follows'; end if;
  key := least((select auth.uid())::text, other_user::text) || ':' || greatest((select auth.uid())::text, other_user::text);
  insert into public.conversations(direct_key) values(key) on conflict(direct_key) do update set direct_key=excluded.direct_key returning id into conversation_uuid;
  insert into public.conversation_members(conversation_id,user_id) values(conversation_uuid,(select auth.uid())),(conversation_uuid,other_user) on conflict do nothing;
  return conversation_uuid;
end $$;
revoke all on function public.start_direct_conversation(uuid) from public, anon;
grant execute on function public.start_direct_conversation(uuid) to authenticated;
create or replace function public.enforce_message_membership() returns trigger language plpgsql security definer set search_path = '' as $$
declare other_user uuid;
begin
  if (select count(*) from public.conversation_members where conversation_id=new.conversation_id) <> 2 then raise exception 'direct conversations require exactly two members'; end if;
  select user_id into other_user from public.conversation_members where conversation_id=new.conversation_id and user_id<>new.sender_id;
  if other_user is null or not private.is_mutual(other_user) then raise exception 'direct messages require mutual approved follows'; end if;
  return new;
end $$;
create trigger messages_membership before insert on public.messages for each row execute procedure public.enforce_message_membership();
create or replace function public.create_social_notification() returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid; kind_value public.notification_kind; comment_uuid uuid; actor uuid; post_uuid uuid;
begin
  actor := coalesce((to_jsonb(new)->>'user_id')::uuid,(to_jsonb(new)->>'author_id')::uuid,(to_jsonb(new)->>'follower_id')::uuid);
  post_uuid := (to_jsonb(new)->>'post_id')::uuid;
  if tg_table_name='likes' then select author_id into recipient from public.posts where id=post_uuid; kind_value := 'like';
  elsif tg_table_name='comments' then select author_id into recipient from public.posts where id=post_uuid; kind_value := case when (to_jsonb(new)->>'parent_id') is null then 'comment'::public.notification_kind else 'reply'::public.notification_kind end; comment_uuid := (to_jsonb(new)->>'id')::uuid;
  else
    if tg_op='UPDATE' and (to_jsonb(new)->>'status')='approved' then
      recipient := (to_jsonb(new)->>'follower_id')::uuid; actor := (to_jsonb(new)->>'following_id')::uuid; kind_value := 'follow_approval';
    else
      recipient := (to_jsonb(new)->>'following_id')::uuid; kind_value := case when (to_jsonb(new)->>'status')='requested' then 'follow_request'::public.notification_kind else 'follow'::public.notification_kind end;
    end if;
  end if;
  if recipient is not null and recipient <> actor then
    insert into public.notifications(recipient_id,actor_id,kind,post_id,comment_id) values(recipient,actor,kind_value,case when tg_table_name in ('likes','comments') then post_uuid else null end,comment_uuid);
  end if;
  return new;
end $$;
create trigger likes_notify after insert on public.likes for each row execute procedure public.create_social_notification();
create trigger comments_notify after insert on public.comments for each row execute procedure public.create_social_notification();
create trigger follows_notify_insert after insert on public.follows for each row execute procedure public.create_social_notification();
create trigger follows_notify_approval after update of status on public.follows for each row when (old.status is distinct from new.status) execute procedure public.create_social_notification();

create or replace function public.search_public(search_text text, cuisine_filter text default null, neighborhood_filter text default null, price_filter smallint default null)
returns table(kind text, id uuid, label text, subtitle text, score real) language sql stable security invoker set search_path = '' as $$
  with q as (select lower(trim(search_text)) needle), results as (
    select 'restaurant'::text kind,r.id,r.name label,coalesce(r.neighborhood,r.address) subtitle,case when lower(r.name)=(select needle from q) then 100 else similarity(lower(r.name),(select needle from q)) end score from public.restaurants r,q where not r.is_removed and (lower(r.name) % q.needle or exists(select 1 from public.restaurant_aliases a where a.restaurant_id=r.id and a.normalized_alias % q.needle)) and (cuisine_filter is null or r.cuisine=cuisine_filter) and (neighborhood_filter is null or r.neighborhood=neighborhood_filter) and (price_filter is null or r.price_level=price_filter)
    union all select 'dish',d.id,d.name, r.name,case when lower(d.name)=(select needle from q) then 100 else similarity(lower(d.name),(select needle from q)) end from public.dishes d join public.restaurants r on r.id=d.restaurant_id,q where not d.is_removed and not r.is_removed and (lower(d.name) % q.needle or exists(select 1 from public.dish_aliases a where a.dish_id=d.id and a.normalized_alias % q.needle))
    union all select 'user',p.id,p.username,p.display_name,case when lower(p.username)=(select needle from q) then 100 else similarity(lower(p.username),(select needle from q)) end from public.profiles p,q where p.visibility='public' and p.suspended_at is null and lower(p.username) % q.needle
    union all select 'collection',c.id,c.title,p.username,case when lower(c.title)=(select needle from q) then 100 else similarity(lower(c.title),(select needle from q)) end from public.collections c join public.profiles p on p.id=c.owner_id,q where c.is_public and p.visibility='public' and p.suspended_at is null and lower(c.title) % q.needle
  ) select * from results order by score desc,label limit 60;
$$;
create or replace function public.merge_dish(source_dish uuid, target_dish uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() or source_dish=target_dish then raise exception 'admin role required'; end if;
  if exists(select 1 from public.post_dishes where dish_id=source_dish and post_id in (select post_id from public.post_dishes where dish_id=target_dish)) then raise exception 'cannot merge dishes that co-occur in a post'; end if;
  insert into public.dish_aliases(dish_id,alias) select target_dish,name from public.dishes where id=source_dish on conflict do nothing;
  insert into public.dish_aliases(dish_id,alias) select target_dish,alias from public.dish_aliases where dish_id=source_dish on conflict do nothing;
  update public.post_dishes set dish_id=target_dish where dish_id=source_dish;
  update public.dishes set is_removed=true where id=source_dish;
  insert into public.record_merge_history(actor_id,record_type,source_id,target_id) values((select auth.uid()),'dish',source_dish,target_dish);
end $$;
create or replace function public.merge_restaurant(source_restaurant uuid, target_restaurant uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() or source_restaurant=target_restaurant then raise exception 'admin role required'; end if;
  insert into public.restaurant_aliases(restaurant_id,alias) select target_restaurant,name from public.restaurants where id=source_restaurant on conflict do nothing;
  insert into public.restaurant_aliases(restaurant_id,alias) select target_restaurant,alias from public.restaurant_aliases where restaurant_id=source_restaurant on conflict do nothing;
  update public.posts set restaurant_id=target_restaurant where restaurant_id=source_restaurant;
  update public.dishes set restaurant_id=target_restaurant where restaurant_id=source_restaurant;
  update public.restaurants set is_removed=true where id=source_restaurant;
  insert into public.record_merge_history(actor_id,record_type,source_id,target_id) values((select auth.uid()),'restaurant',source_restaurant,target_restaurant);
end $$;
revoke all on function public.merge_dish(uuid,uuid), public.merge_restaurant(uuid,uuid) from public, anon;
grant execute on function public.merge_dish(uuid,uuid), public.merge_restaurant(uuid,uuid) to authenticated;
create or replace function private.can_read_post_media(object_name text) returns boolean language sql stable security definer set search_path = '' as $$ select (storage.foldername(object_name))[1]=(select auth.uid()::text) or ((storage.foldername(object_name))[2] ~* '^[0-9a-f-]{36}$' and private.can_view_post((storage.foldername(object_name))[2]::uuid)) $$;
revoke all on function private.can_read_post_media(text) from public, anon, authenticated;
drop policy post_media_select on storage.objects;
create policy post_media_select on storage.objects for select to authenticated using(bucket_id='post-media' and private.can_read_post_media(name));
create policy restaurant_media_select on storage.objects for select to authenticated using(bucket_id='restaurant-media');
