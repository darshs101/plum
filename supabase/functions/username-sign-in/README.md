# Username password login

This endpoint is prepared but has not been deployed; deployment requires the user's instruction. Until it is deployed, email/password login is the available path.

Deploy `username-sign-in` with gateway JWT verification disabled. It validates the password through GoTrue before returning any session. `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are Edge runtime settings only. Do not copy service credentials into the iOS app. No email address is returned by this endpoint.

The function calls the service-role-only `check_username_sign_in_limit` RPC before identity lookup. It stores SHA-256 hashes, with limits of 30 attempts per IP per 5 minutes, 10 per username per 15 minutes, and 300 globally per 5 minutes. The username/global limits also bound clients that spoof forwarding headers. Requests fail closed if the limiter is unavailable. Apply the versioned rate-limit migration before deploying this source.

Before enabling production traffic, verify invalid credentials, suspended accounts, email-unconfirmed accounts, rate-limit responses, and concurrent username changes against the deployed endpoint. That deployment and its end-to-end checks remain outstanding.
