# Plum iOS v1 requirement checklist

Source: `.plans/plum-ios-v1-spec.md`. This is the release checklist; each item needs implementation and an acceptance check before marking complete.

| ID | Requirement | Implementation / acceptance check | Status |
|---|---|---|---|
| R1 | SwiftUI iPhone app; client-neutral API backend | iOS target + Supabase REST/Auth/Storage contracts; build `Plum.app` | Implemented; remote integration blocked |
| R2 | Auth: Apple, Google, email/username/password; stable internal user separate from identities | Supabase Auth config, `profiles`/`auth_identities`, session UI | Gap |
| R3 | Onboarding city/neighborhood, logging/saving prompts, all skippable | SwiftUI onboarding persisted per profile | Gap |
| R4 | Restaurant location: name/address/photo; immediate shared/searchable public record | schema + create/search UI + storage | Gap |
| R5 | Public dish directory; typeahead; no auto merge; duplicate reports + admin merge; aliases resolve | dish/alias tables, RPC/search, report/admin operations | Gap |
| R6 | Create/edit/delete multi-dish post at one restaurant; 0.5–5 half stars; photo required; optional caption/date; slideshow | transactional post API, composer, Photos upload, edit/delete tests | Gap |
| R7 | Public restaurant/dish aggregates and activity; latest eligible user rating; private excluded | aggregate query/views/RPC and policy tests | Gap |
| R8 | Public/private profiles and approval-based follows; follower removal; privacy across all surfaces | `follows` policies + visibility helpers + profile/follow UI + two-user RLS tests | Gap |
| R9 | Profile identity/counts, visual review grid, public collections/rankings | profile screen with live data/states | Partial (placeholder only) |
| R10 | Saved Places private default; public/private unranked/ranked collections; restaurant/post items; manual rank | collections schema, RLS, collection UI/reordering | Gap |
| R11 | Visible users like/comment/reply; own/owner comment delete; mutual-only mentions; notifications | social schema/RLS/triggers, UI and notification list | Gap |
| R12 | Mutual-follow one-to-one text/post-share DMs; realtime/member guard | conversation schema/RLS/realtime UI | Gap |
| R13 | Chronological following-only Home; useful Atlanta starter state | feed query/UI, pagination/loading/empty/error | Partial (local fixture only) |
| R14 | Explore public-only: exact-prioritized free-text restaurants/dishes/users/collections; filters; curated/nearby/popular | search RPC/indexes + Explore states | Partial (local fixture only) |
| R15 | Icon-only four-tab navigation; Profile bell notifications | tab correctness + notifications screen | Partial (placeholder only) |
| R16 | Push: like/comment/reply/follow/request/approval; device permission/token/APNs server handling | device tokens, server triggers/function, permission registration | Gap |
| R17 | Report posts/accounts/photos and admin console: triage/remove/edit/merge/suspend/audit | reports/admin schema and admin console/API | Gap |
| R18 | Original/transformed post/restaurant media; private permission-aware delivery | storage buckets/policies/upload + signed URL delivery test | Gap |
| R19 | RLS structural privacy, data preservation, migrations, no service role in client | additive migration + policy test scaffold committed; remote advisor/policy execution pending project access | Implemented locally; remote verification blocked |
| R20 | Loading, empty, error, permissions, persistence after relaunch and separate-account restrictions | observable stores/UI; simulator validates retryable unconfigured state; two-account persistence/RLS tests pending project access | Partial; remote verification blocked |

## Current evidence / blockers

- 2026-11-03: `swift build` passes; XcodeGen regenerated `Plum.xcodeproj`; `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` produced `Plum.app`; the app installed and launched on iPhone 17 Pro (iOS 26.5).
- The workspace has no Supabase project ref, management token/MCP connection, project URL, or publishable key. The versioned migration was **not applied**. Until those are provided, live auth/data/media, APNs configuration, migration/advisor execution, and separate-account privacy/persistence testing cannot be honestly marked complete.

## Out of scope guardrails

No maps, reservation/menu/delivery, algorithmic Home ranking, Android, group/photo DMs, blocking/muting, user directory editing, pre-publication restaurant moderation, automatic duplicate merging, email verification/age gate/mandatory consent, or favorite cuisine/neighborhood profile fields.
