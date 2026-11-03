# Username password login

This endpoint is prepared but has not been deployed; deployment requires the user's instruction. Until it is deployed, email/password login is the available path.

Deploy `username-sign-in` with gateway JWT verification disabled. It validates the password through GoTrue before returning any session. `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are Edge runtime settings only. Do not copy service credentials into the iOS app. No email address is returned by this endpoint.

Before enabling production traffic, configure an endpoint/IP rate limit and test invalid credentials, disabled/suspended accounts, email-unconfirmed accounts, and concurrent username changes. GoTrue applies its authentication limits, but an additional edge limit is required to cover username-resolution traffic.
