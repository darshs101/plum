# Notifications, chat bubbles, and comment replies

The saved specification and requirement checklist include these user amendments.

| Behavior | Implementation | Acceptance |
| --- | --- | --- |
| Live unread bell count | Shared recipient-scoped realtime subscription, exact unread count, foreground reconnect and session reset | Separate-account events change the visible bell 0→1→2; count clears on opening Notifications, remains 0 after relaunch, and returns to 1 for a subsequent comment |
| Read state belongs to the recipient | Invoker-security `mark_notifications_viewed()` uses authenticated recipient predicate and existing RLS | Another account calling the RPC leaves the recipient's unread count unchanged |
| Inline Follow back | Latest eligible follow row offers Follow back, then Following or Requested; current pending requests retain Confirm/Delete | Simulator approves a private requester and follows the now-public actor back inline. Separate API check confirms private follow-back stays requested and does not establish mutual messaging |
| Message direction and colors | Full-width rows place sent bubbles right with purple background/white text; received bubbles left with gray background | Simulator asserts positions and Sent/Received accessibility values; exported screenshots visually confirm both colors and alignment |
| Collapsed comment replies | Per-parent Show replies / Hide replies controls, nested reply groups, focus on Reply, auto-expand after sending | Simulator verifies sibling/nested replies, unrelated root comments, collapse/expand, sends a real reply and reveals it again after app relaunch; API confirms the saved parent relationship |

## Verification evidence

- `/tmp/PlumBellChatAndReplies.xcresult`: 2 simulator tests passed, 0 failures (112.149 seconds): `testBellUnreadFollowBackAndMessageBubbles` and `testCommentReplyDropdownsAndPersistence`.
- `/tmp/plum-bell-chat-replies-tests.log`: full simulator test output. The first reply test attempt exposed an ambiguous accessibility query across diary cards; the query now selects the first matching composer. The final combined run passed.
- `/tmp/plum-bell-chat-attachments`: inspected bell-count, chat-bubble and nested-reply screenshots. In particular `58A76269-6184-42DF-9B76-0E04BFDDA676.png` shows badge 1, `F79E473C-7160-48A5-B7B8-89F3C13FE0BD.png` shows both bubble directions/colors, and `35A2ADD9-E81B-46A4-B134-0746098B7C4B.png` shows nested replies.
- Package check: `/tmp/plum-bell-chat-domain-tests.log`, `swift test`, 4 tests passed. This is separate from the application build.
- Actual app build: `/tmp/plum-notifications-chat-final-build.log`, `BUILD SUCCEEDED`, after final cancellation/visibility guards and shared-post destination tint correction. Produces `/tmp/plum-root-final/Build/Products/Debug-iphonesimulator/Plum.app`, bundle `com.plum.app`.
- `/tmp/plum-bell-chat-final-test-compile.log`: `TEST BUILD SUCCEEDED` confirms the final test sources and app compile, including unique reply text for safe repeat runs.
- Final app installed and launched on the original iPhone 18 Pro simulator (`DE2DAAE8-4A9B-4BF3-B23A-0F056E92756F`) with the user's session preserved. Automated acceptance used the separate Plum Social QA simulator, which was shut down afterward.

Applied additive migration `20261104031539_notification_read_state_and_realtime` to connected project `rsqrxmokdqgwnxtreihp`. It adds an authenticated invoker read-state RPC, a partial unread-recipient index and notifications to the existing realtime publication. Existing recipient-only RLS and column grants remain enforced; no destructive schema changes or client service credentials. Security advisors show no warning for the new invoker function; previous guarded-definer warnings, private limiter-table INFO and disabled leaked-password protection remain.

Only isolated QA fixture posts/restaurants are soft-removed after acceptance. Credentials and test xcconfigs stay outside the repository. The final tiny cancellation/visibility guards and shared-post tint correction were app-build checked after the passing simulator run; they were not separately rerun in UI tests. Private follow-back was API checked rather than a second UI approval run. This report verifies the requested changes; broader v1 acceptance gaps and external Apple/Google/APNs setup remain tracked in `docs/V1_REQUIREMENTS.md`.
