# Live simulator integration tests

These tests use a real Supabase account and persist posts. Run only against isolated QA accounts, not your personal account.

The Xcode test target receives `PLUM_QA_EMAIL` and `PLUM_QA_PASSWORD` from an external xcconfig. Keep that file outside the repository. The associated account must have completed onboarding, own a private Saved Places collection containing the isolated `Plum Integration Atlanta` restaurant fixture, and have a private profile. Add an image to the simulator photo library before running the composer test.

The suite checks photo publishing, real account data, search/navigation, session persistence after relaunch, and sign-out. Backend/RLS/Realtime scripts in `scripts/` accept external configuration and QA credential files; no credentials are checked into source control. See `docs/FUNCTIONAL_VERIFICATION.md` for the actual run evidence and limitations.
