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

## November 3 follow-up audit

- Hosted Confirm email was turned off by the project owner. Two fresh accounts were created through the public Auth signup endpoint and received sessions. A separate fresh simulator signup, skip onboarding, profile load, terminate/relaunch, and sign-out passed `/tmp/PlumAuditFreshSignup5.xcresult` (1 test, 0 failures).
- Applied five additive remote migrations: `post_photo_link_contract`, `username_sign_in_rate_limit`, `device_token_validation_fix`, `follows_grants_repair`, and `follow_status_normalization`. Remote and local migration versions match. No existing content was dropped.
- Fresh two-account checks found and fixed follows table grants. A private stranger cannot read a post or resolve the private identity, then an approved follower can; public follow is immediate. Mutual conversation start succeeds. Register/unregister of a device token returned 204. Atomic `save_post` persisted a photo-to-dish link.
- Composer and edit flows now offer live selection and correct multi-dish photo links. Explore has cuisine/neighborhood/price controls and live popular dishes. Home has live Atlanta account suggestions. Social inbox/realtime reconnect, notifications, and follow-action state have loading/retry fixes. These source changes built as a combined iOS target; full UI flow acceptance is still in progress.
- The first combined photo-post UI run exposed an omitted-null RPC request: empty caption/date caused `save_post` to miss the new seven-argument signature. `SavePostParams` now explicitly encodes both optional keys as JSON null. The repaired simulator flow published a two-dish photo post successfully.
- Added the missing `send_message_with_share` RPC in `20261104012142_atomic_message_share`, with security invoker semantics so membership RLS and mutual-follow triggers remain authoritative. `scripts/verify_atomic_messages.py` passed text send, post sharing, complete rollback on invalid share, and rejection after an unfollow, then restored the isolated fixture follow.
- The repaired location-detail UI now tolerates an unavailable photo, preserving activity and save actions. `/tmp/PlumAuditDetails.xcresult` passed profile, Saved Places, terminate/relaunch, Explore search, and restaurant detail. `/tmp/PlumAuditCoreFlows3.xcresult` passed photo publishing; later separate tests cover the repaired detail path. Failures from earlier attempts are retained in their result bundles rather than represented as passing suites.
- Latest standalone application build: `/tmp/plum-final-app-build.log` reports `BUILD SUCCEEDED`, producing `/tmp/plum-root-final/Build/Products/Debug-iphonesimulator/Plum.app` (`com.plum.app`). `swift build` separately passes the domain package. Deno type checks pass both Edge Function sources; that does not establish deployment or delivery.
- `/tmp/PlumAuditPostEdit2.xcresult` passes the real post like/comment/edit persistence flow. The edit keeps the existing dish and media references and displays the changed caption after saving. The suite also returns the app to signed-out state.
- Final app was installed and launched as `com.plum.app` on simulator `DE2DAAE8-4A9B-4BF3-B23A-0F056E92756F` (iPhone 18 Pro). `/tmp/plum-audit-final.png` was inspected and shows Plum's welcome screen. Isolated audit profiles were made private and their restaurant fixtures soft-removed after testing; records were preserved and no real user content was deleted.
- Username Edge source now calls the server-only rate limit function before resolving identity. The APNs worker includes notification route metadata and retains tokens on an APNs `BadDeviceToken` response so environment mismatches can be corrected. Neither Edge function has been deployed.

## External blockers and unverified paths

1. Hosted email confirmation is now disabled. Fresh public signup, onboarding skip, relaunch, and sign-out have passed simulator acceptance. Other optional onboarding actions remain to be walked through.
2. Hosted Auth reports Apple and Google providers disabled. Enable them with the actual provider credentials; configure `plum://login-callback` in the redirect allowlist. Add the Sign in with Apple capability and development team in Xcode. Provider end-to-end sign-in is unverified until then.
3. APNs credentials/capabilities and authorized Edge Function deployment/scheduling are required. See `supabase/functions/dispatch-notifications/README.md`. Push delivery is unverified.
4. A real staff user needs a server-assigned `app_metadata.plum_role=admin`; ordinary accounts cannot assign themselves this role. Moderation API checks use an isolated QA admin claim which is removed after testing. The admin UI has not been walked through with a staff account.
5. Username is selected during signup. Username-password client/Edge source and a server-side IP/username/global limiter are prepared in `supabase/functions/username-sign-in`; deployment is withheld under the user’s no-deployment instruction. Until then use email/password. Username-only login is unverified.
6. The database has no approved editorial seed data. Do not describe synthetic QA records as Atlanta recommendations. Curated/local discovery can only display the actual shared records and curated collections present in the project.
7. Full UI coverage for editing/deleting posts, every follow/collection/report action, realtime reconnection, large media, VoiceOver, and every failure state remains to be completed. Passing the core simulator flows is not full v1 sign-off.

Final database advisor review reports seven intentional authenticated security-definer RPC warnings (five admin-gated mutations, the identity-only direct-link lookup, and mutual-DM creation) plus disabled leaked-password protection. None contains a service key in the client. Staff-role and non-admin denial checks cover the tested mutation paths; this is not a full independent security audit.
