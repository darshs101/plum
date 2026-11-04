# APNs worker setup

The worker is implemented but has not been deployed or tested with Apple credentials.

1. In Apple Developer, enable Push Notifications and Sign in with Apple for `com.plum.app`. Select the development team in Xcode and add those capabilities under Signing & Capabilities. Use a physical device for the final APNs delivery check.
2. Create an APNs signing key. Set Edge Function secrets `APNS_PRIVATE_KEY` (P8 PEM), `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID=com.plum.app`, `APNS_ENVIRONMENT=sandbox` (production for release), and a random `PLUM_PUSH_WORKER_SECRET`. Never put these in the app, xcconfig, or source control.
3. After deployment is authorized, deploy `dispatch-notifications` with gateway JWT verification disabled. It authenticates its caller with the separate worker secret. Configure a private scheduler to POST to it with `Authorization: Bearer <PLUM_PUSH_WORKER_SECRET>` every minute. The service-role credential is used only inside the Edge runtime.
4. Sign into Plum on a signed physical-device build, enable notifications from Profile, and create a like/comment/reply/follow/request/approval from a second account. Confirm delivery and `notification_outbox.delivered_at` for every event. Denied devices must receive no push.

The outbox is at-least-once: a retry after a partial device-delivery failure may deliver the same notification twice. Notification IDs are included for client deduplication. No notification text or photo URLs from private content are sent in APNs payloads.
