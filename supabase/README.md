# Supabase deployment and verification

This folder is an imperative migration project. No remote project has been modified from this workspace: the Supabase CLI and MCP connection are not available here.

1. Install the current Supabase CLI and authenticate with a scoped project token.
2. `supabase link --project-ref <your-project-ref>`
3. Inspect the target first: `supabase migration list` and `supabase db pull pre_plum_audit --linked --yes`. Commit/reconcile any existing remote schema before applying this migration.
4. Apply once: `supabase db push`, then run `supabase db advisors` and `supabase test db` with a local database.
5. In Dashboard Auth, enable Apple, Google, and email/password. Configure the iOS redirect URL. Do not put provider secrets or service-role credentials in the app.
6. Configure APNs credentials in a server-only Edge Function that drains `notification_outbox`; the database deliberately only creates the outbox event.

Before release, execute the two-account acceptance matrix: stranger cannot select a private profile/post/photo/collection; approved follower can; private ratings do not enter `public_*_aggregates` or `search_public`; non-members cannot read/send direct messages; private-storage signed URL is granted only after a post visibility check.
