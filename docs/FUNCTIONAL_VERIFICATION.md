# Plum functionality repair evidence — 2026-11-03

The previous app was not functional merely because it compiled. It hid signup errors, treated confirmation-pending accounts as signed in, used separate Auth clients, lacked the required RLS helper execution grants, had recursive conversation policies, and rendered inert navigation/actions.

## Implemented repairs

- One session-bound Supabase client for Auth, REST, Storage, and Realtime. Explicit create-account and sign-in forms; username/password validation; errors and loading states; confirmation-pending flow; email-link callback; real Apple ID-token exchange and Google OAuth; server-persisted skippable onboarding; sign out.
- Required Supabase settings now reach the compiled Info.plist; xcconfig URLs use `https:/$()/...` to avoid `//` comment truncation. XcodeGen preserves this configuration when regenerating the project.
- Live restaurant/photo creation, dish suggestions with retained dish IDs, normalized photo previews and private originals, atomic multi-dish posts, edits/deletes, and signed media delivery. Cancelled typeahead requests no longer overwrite current results or show as user errors.
- Navigable Explore, restaurant/dish public activity and aggregates, profiles/visual grids/counts, Saved Places and other collections/rankings, likes/comments/replies, mutual mentions, follow requests/approval/removal, notifications, one-to-one mutual messages and post shares, report submission, and an admin console.
- Server protection against approval bypass, mutable admin/identity columns, forged curation, suspended-account writes, invalid direct post writes, nonexistent photo uploads, non-mutual mentions, and cross-post replies. Merge aliases and collection references are preserved; co-occurring duplicate dish ratings are recorded in the admin audit when collapsed into one dish entry. Local migration versions were aligned with the recorded hosted versions to prevent reapplication.
- Device permission/token registration and a server APNs outbox worker are present. Apple capabilities, credentials, deployment, scheduling, and physical-device delivery remain external setup, not verified functionality.

## Verification completed

- Domain package: `swift build` passes. This is separate from the iOS app build.
- Actual iOS target: Debug `xcodebuild` builds `Plum.app` for iPhone 18 Pro (iOS 27.0 simulator).
- Live Supabase: `scripts/verify_supabase.py` passed 34 checks with two isolated, confirmed integration accounts. These accounts were provisioned explicitly for integration; this does not prove public signup works.
- Additional live checks deny forged approval of a private follow, self-editing suspension status, and self-curated collections.
- `scripts/verify_moderation.py` verifies mentions, reply notification recipients, persisted reports, admin-only edits/triage, suspended existing-session write denial, incomplete post denial, dish alias merge, and atomic ranked-list order.
- `scripts/verify_realtime.mjs` received a live inserted message as the second mutual follower through Supabase Realtime.
- Simulator XCTest runs cover real email/password sign-in to an integration account, onboarding, profile, private Saved Places, session persistence after terminate/relaunch, Explore search/detail, and publishing a two-dish post using the system photo picker. Result bundles are in `/tmp/PlumFunctionalTests*.xcresult`. Final result: `/tmp/PlumFunctionalTestsReleaseReview2.xcresult` passed all 3 tests (0 failures), including final sign-out. The isolated QA storage/data/accounts and temporary admin claim were cleaned up after verification.

## External blockers and unverified paths

1. Hosted Auth currently returns `mailer_autoconfirm=false`; public signup returned HTTP 429 `over_email_send_rate_limit`. For the specified immediate signup flow, in Supabase → Authentication → Sign In / Providers → Email, disable **Confirm email** and save. The local `supabase/config.toml` setting does not change hosted settings. Then verify a fresh signup in the simulator; do not mark signup complete until that succeeds.
2. Hosted Auth reports Apple and Google providers disabled. Enable them with the actual provider credentials; configure `plum://login-callback` in the redirect allowlist. Add the Sign in with Apple capability and development team in Xcode. Provider end-to-end sign-in is unverified until then.
3. APNs credentials/capabilities and authorized Edge Function deployment/scheduling are required. See `supabase/functions/dispatch-notifications/README.md`. Push delivery is unverified.
4. A real staff user needs a server-assigned `app_metadata.plum_role=admin`; ordinary accounts cannot assign themselves this role. Moderation API checks use an isolated QA admin claim which is removed after testing. The admin UI has not been walked through with a staff account.
5. Username is selected during signup. Username-password client/Edge source is now prepared in `supabase/functions/username-sign-in`; deployment is withheld under the user’s no-deployment instruction. Deploy and configure endpoint/IP rate limiting before enabling it. Until then use email/password. Username-only login is unverified.
6. The database has no approved editorial seed data. Do not describe synthetic QA records as Atlanta recommendations. Curated/local discovery can only display the actual shared records and curated collections present in the project.
7. Full UI coverage for editing/deleting posts, every follow/collection/report action, realtime reconnection, large media, VoiceOver, and every failure state remains to be completed. Passing the core simulator flows is not full v1 sign-off.

Final database advisor review reports seven intentional authenticated security-definer RPC warnings (five admin-gated mutations, the identity-only direct-link lookup, and mutual-DM creation) plus disabled leaked-password protection. None contains a service key in the client. Staff-role and non-admin denial checks cover the tested mutation paths; this is not a full independent security audit.
