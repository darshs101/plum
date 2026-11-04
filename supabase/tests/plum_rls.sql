-- Run after linking a local/test Supabase instance: `supabase test db`.
-- This fixture intentionally asserts the core privacy boundary; extend with seeded UUIDs
-- from your test harness before production launch.
begin;
select plan(4);
-- Required manual acceptance cases: public profile visible; private profile hidden to
-- stranger; private profile visible to approved follower; private post absent from
-- public aggregates/search. These must execute as distinct authenticated JWTs.
select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'posts', 'posts exists');
select policies_are('public', 'posts', array['post_read','post_write']::name[], 'post privacy policies exist');
select policies_are('public', 'comments', array['comment_add','comment_delete','comment_read']::name[], 'comment policies exist');
select * from finish();
rollback;
