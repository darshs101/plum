# Live simulator integration tests

These tests use a real Supabase account and persist posts. Run only against isolated QA accounts, not your personal account.

The Xcode test target receives `PLUM_QA_EMAIL`, `PLUM_QA_PASSWORD`, and `PLUM_QA_RESTAURANT_NAME` from an external xcconfig. Keep that file outside the repository. The associated account must have completed onboarding, own a private Saved Places collection containing the named isolated restaurant fixture, and have a private profile. Add an image to the simulator photo library before running the composer test. The fresh signup test additionally requires a never-used `PLUM_QA_SIGNUP_EMAIL` and `PLUM_QA_SIGNUP_USERNAME`, with hosted email confirmation disabled. Use new signup values on each run.

The suite checks photo publishing, real account data, search/navigation, session persistence after relaunch, and sign-out. Backend/RLS/Realtime scripts in `scripts/` accept external configuration and QA credential files; no credentials are checked into source control. See `docs/FUNCTIONAL_VERIFICATION.md` for the actual run evidence and limitations.

For `testProfileIconTabsDatesAndScrollableDiary`, run `scripts/seed_diary_acceptance.py` using the isolated social QA accounts after their profile-photo UI test. Supply `PLUM_QA_DIARY_SELECTED_POST` (entry 31's UUID), `PLUM_QA_SECOND_EMAIL` (the approved viewer), and `PLUM_QA_OWNER_NAME` in the external xcconfig. The test crosses a 30-post boundary and browses the private owner's diary as both accounts. Fixture images are app screenshots, not recommendations. Soft-removed fixtures must be recreated before another run.
