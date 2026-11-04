-- RLS policies do not run until the role has the underlying table operation grant.
grant select, insert, update, delete on table public.follows to authenticated;
