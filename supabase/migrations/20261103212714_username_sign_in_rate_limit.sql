-- Server-only throttle for a future username-to-email sign-in resolver. Hashes are
-- one-way SHA-256 values supplied by the Edge Function; no raw IP/email/password is stored.
create table private.username_sign_in_attempts (
  id bigint generated always as identity primary key,
  ip_hash text not null check(ip_hash ~ '^[0-9a-f]{64}$'),
  username_hash text not null check(username_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now()
);
create index username_sign_in_attempts_ip_created_idx on private.username_sign_in_attempts(ip_hash,created_at desc);
create index username_sign_in_attempts_username_created_idx on private.username_sign_in_attempts(username_hash,created_at desc);
create index username_sign_in_attempts_created_idx on private.username_sign_in_attempts(created_at desc);
alter table private.username_sign_in_attempts enable row level security;
revoke all on table private.username_sign_in_attempts from public,anon,authenticated;

create or replace function public.check_username_sign_in_limit(ip_hash text, username_hash text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare now_value timestamptz:=now(); ip_count integer; username_count integer; global_count integer;
begin
  if ip_hash !~ '^[0-9a-f]{64}$' or username_hash !~ '^[0-9a-f]{64}$' then raise exception 'hash format required'; end if;
  -- Serializes the small fixed-window decision; avoids a concurrent burst slipping past counts.
  perform pg_advisory_xact_lock(873421);
  delete from private.username_sign_in_attempts where created_at < now_value - interval '1 hour';
  select count(*) into ip_count from private.username_sign_in_attempts where ip_hash=check_username_sign_in_limit.ip_hash and created_at>=now_value-interval '5 minutes';
  select count(*) into username_count from private.username_sign_in_attempts where username_hash=check_username_sign_in_limit.username_hash and created_at>=now_value-interval '15 minutes';
  select count(*) into global_count from private.username_sign_in_attempts where created_at>=now_value-interval '5 minutes';
  if ip_count>=30 or username_count>=10 or global_count>=300 then return false; end if;
  insert into private.username_sign_in_attempts(ip_hash,username_hash) values(check_username_sign_in_limit.ip_hash,check_username_sign_in_limit.username_hash);
  return true;
end $$;
revoke all on function public.check_username_sign_in_limit(text,text) from public,anon,authenticated;
grant execute on function public.check_username_sign_in_limit(text,text) to service_role;
