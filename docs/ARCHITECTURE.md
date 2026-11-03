# Plum v1 shared architecture and contracts

## Boundaries

`PlumDomain` defines `Codable`, client-neutral DTOs and repository protocols. `PlumApp` owns SwiftUI screens and observable feature stores. `SupabasePlumRepository` is the only client data boundary: it uses the authenticated user's JWT with PostgREST/RPC and Storage; it never contains a service-role key. Server authority lives in versioned SQL migrations, RLS policies, safe RPCs, triggers, and Edge Functions for APNs.

## Identity and visibility contract

`profiles.id = auth.users.id`. Visibility is server-evaluated: public profile data is visible to authenticated visitors; private profile data is visible only to its owner or an approved follower. Public discovery, public activity and aggregates exclude private-account content. Mutual follow is two approved directed `follows` rows. All client writes run under `auth.uid()` RLS predicates.

## Content contract

A `posts` row has one restaurant. Its `post_dishes` children each point to a dish at that restaurant and contain a half-step rating. Its `post_photos` children meet the one-or-more photo rule. A transaction/RPC validates the invariant on create/update. Deleting a post retains `collection_items` referring to it (they become unavailable links, not cascaded deletes). Dish and restaurant merges update foreign keys transactionally and store aliases/history.

## Repository surface (stable names)

`SessionRepository`: restore session, sign in/up/out, provider OAuth, onboarding profile.

`DirectoryRepository`: search(query, filters), createRestaurant, createDish, resolveAlias, restaurantDetail, dishDetail.

`PostRepository`: feed(cursor), createPost, updatePost, deletePost, toggleLike, comments, createComment, deleteComment, report.

`SocialRepository`: profile, follow/request/approve/remove, collections, notifications, conversations/messages/post shares.

Each operation returns typed DTOs or a user-presentable typed error. Screens must render loading, empty, retryable error, and permission-denied states rather than fixtures.

## Database entities and server actions

Core tables follow the v1 entity list: profiles/auth_identities/device_tokens/follows; restaurants/aliases/dishes/aliases; posts/post_dishes/post_photos/photo_dish_links; likes/comments/comment_mentions; collections/items; conversations/members/messages/post_shares; notifications; reports/admin_actions/record_merge_history. Database RPCs provide atomic post validation, ranked collection moves, exact-boosted public search, privacy-safe activity/aggregates, and admin-only merges. Storage object paths begin with immutable owner UUID (`post-media/<user>/<post>/...`, `restaurant-media/<user>/<restaurant>/...`).

## Ownership / dependency order

1. Coordinator: this document, requirement evidence, Xcode/shared config, dependency integration.
2. Backend worker: migrations, policy tests, storage/server contracts. It must not edit SwiftUI screens.
3. Composer/directory worker: only Create/Explore screens plus stores/adapters consuming the contract; it may not alter schema or social screens.
4. Social worker: only Home/Profile/social/onboarding/notification screens plus stores/adapters consuming the contract; it may not alter schema or composer/directory screens.

Backend contracts are accepted first; client workers may create compiling interfaces/stubs which the coordinator binds to the implementation.

## Runtime integration corrections

All app adapters share `PlumServices.client`; independent client instances must not own separate auth sessions. `PlumAPI` owns typed live social reads and actions; `SupabaseDirectoryService` owns directory/composer requests. Both use the same JWT, Storage, and Realtime client.

Photo uploads keep a bounded, orientation-normalized JPEG at the linked storage path and the original at `<storage_path>.original`. Both are private and use the same owner/post folder permission model. Display uses short-lived signed URLs. Post writes go through `save_post`; deferred constraints also reject incomplete direct table writes at commit.

XcodeGen writes the Supabase build-setting placeholders into the source Info.plist. An xcconfig URL must be written `https:/$()/PROJECT.supabase.co` so Xcode does not treat `//` as a comment. The project URL/publishable key belong in the ignored `Config/Secrets.xcconfig`; server/APNs secrets never belong there.
