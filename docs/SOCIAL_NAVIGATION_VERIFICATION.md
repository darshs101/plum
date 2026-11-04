# Profile, notifications, collections, and Messages update

User-directed changes supersede the original four-tab specification; the saved spec and requirement checklist now include the five-tab layout.

| Requested behavior | Implementation | Acceptance evidence |
| --- | --- | --- |
| Flat Instagram-style notifications | Plain chronological rows with actor avatar/initial, readable event copy and time; paginated history; inline Confirm/Delete for the current follow request | Simulator opens notifications, verifies no Manage follow requests entry, opens a private requester as a locked profile, and approves inline |
| Ranked restaurant labels in collections | Numbered restaurant names, plus dish/rating summaries for saved posts; post links still open the individual tasting | API nested join and simulator verify restaurant name and `1.`; generic Open saved tasting label absent |
| Profile gear Settings opposite bell | Gear left, bell right; Settings holds Edit profile, Enable notifications, Sign out, and follower management | Simulator verifies these actions absent from profile body, present in Settings, and sign-out works |
| Uploaded profile pictures | System photo picker; normalized JPEG up to 5MB; private `profile-media`; signed URLs; own-path and uploaded-object validation | Simulator picks and uploads a photo, saves, relaunches and displays it; fresh REST download confirms a 120,177-byte JPEG |
| Dedicated Messages tab after Create | Five icons: Home, Explore, Create, Messages, Profile; all mutual approved friends, including friends with no conversation | Simulator verifies five tabs, sends a real message, and checks ordered friend rows with an uploaded friend picture |
| Latest message, then last followed | `friends_inbox()` uses membership/profile RLS, latest-message lateral lookup, and mutual-follow timestamp fallback; inbox subscribes to message changes | Live multi-account checks verify ordering before messages, reordering after messages, unmessaged friends last, and unrelated accounts' empty inbox |

## Verification

- Package check: `swift build` passed separately.
- Actual application: `/tmp/plum-social-final-build.log` reports `BUILD SUCCEEDED`; output `/tmp/plum-root-final/Build/Products/Debug-iphonesimulator/Plum.app`, bundle `com.plum.app`.
- Backend: `scripts/verify_profile_social.py` completed against the connected project with four isolated signup accounts. It verifies upload ownership, private stranger denial, approved follower photo signing, rejection of foreign avatar references, recipient-scoped actor identities, inbox ordering, and collection joins. Credentials remain outside the repository.
- `/tmp/PlumSocialNavigation2.xcresult`: 2 tests passed, including social navigation/photo upload/rank labels and sign-out.
- `/tmp/PlumMessagesOrder.xcresult`: ordered friend inbox/avatar visual acceptance and sign-out passed.
- `/tmp/PlumSocialPrivateRequests.xcresult`: final social flow additionally verifies a private requester can be opened as a locked profile before inline approval; sign-out included.
- Screenshots exported under `/tmp/plum-social-final-attachments` were inspected for flat notification rows, ranked restaurant labels and the uploaded profile photo after relaunch. The QA photo is an app screenshot, not production food content.

Tests ran on separate simulator `7CACDFC9-7E01-4DD8-9FF0-0DA8A5F53938`, preserving the user's session on the original iPhone 18 Pro simulator. QA accounts remain private and their restaurant is soft-removed after acceptance so it does not become an Atlanta recommendation.

## Backend change

Applied additive migration `20261104020849_profile_photos_and_social_inbox` to project `rsqrxmokdqgwnxtreihp`; local version matches hosted history. It creates the private profile-media bucket/policies, validates profile-photo references, adds the invoker-security friends inbox, and adds recipient-scoped notification actor identities. No existing account/content was dropped.

The actor RPC intentionally reveals only identities associated with the current user's own notifications. It exposes no private location/activity, and private avatar paths remain restricted to viewers authorized for the profile. The new SECURITY DEFINER advisor warning for that RPC was reviewed with this constraint; previous guarded RPC warnings, the private limiter-table INFO, and disabled leaked-password protection remain. No service credential is present in the app.

Existing external Apple/Google/APNs setup and the remaining broader v1 acceptance matrix are unchanged; this report signs off the requested social-navigation update rather than all v1 behavior.
