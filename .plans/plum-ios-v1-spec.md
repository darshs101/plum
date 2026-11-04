# Plum iOS v1 Product Specification

## Product summary

Plum is a social food journal for Atlanta: a refined, photo-led place for people to log and rate dishes, follow other food lovers, make lists, and discover local food through people they trust. It borrows Letterboxd's profile-and-ranking culture while making the core contribution a dish review at a specific restaurant location.

The iPhone launch should focus on a useful social experience rather than reservations, menus, or an algorithmic recommendation feed. Android is out of scope for v1, but the backend and API design should remain client-neutral.

## Audience and launch

- Initial market: Atlanta, Georgia.
- Primary users: social, local food enthusiasts who want a personal visual record and trusted recommendations from friends.
- Launch positioning: polished editorial food journal with an approachable, playful social layer.
- No defined launch KPI gates. Favor a small, reliable social core that can be expanded after launch.

## Product principles

1. **Dish first, restaurant grounded.** A review always concerns a dish at one restaurant location, never a restaurant as a whole.
2. **A simple record beats a demanding form.** Each dish needs a rating and photo, but text and contextual details are optional.
3. **Privacy is structural.** Private material does not leak into public search, discovery, restaurant activity, or averages.
4. **People before an algorithm.** Home is chronological activity from followed people. Explore is deliberately separate.
5. **Shared directory, accountable curation.** Restaurants and dishes are crowd-added, searchable shared records; admins resolve quality problems.

## Core content model

### Restaurant

A restaurant represents one physical location, not a brand as a whole. Each has a public shared page.

Required when added:

- Name
- Physical location/address
- One photo

Restaurants appear in public search immediately without pre-moderation. Admins can later edit listings, merge duplicates, or remove inappropriate listings. Restaurant pages show a separate public restaurant-level aggregate and recent public activity across their dishes.

### Dish

A dish belongs to one restaurant location and is a public shared record. Anyone may create a dish by posting it. Dishes are searchable even with no reviews.

Before creating one, the composer searches existing dishes and receives typeahead match suggestions. The system must not automatically merge similar names. Users can report possible duplicates; admins decide merges. After a merge, alternate/legacy names remain searchable and resolve to the surviving record.

### Post / visit / review

These are the same object. A post is a visit-like entry with one or more reviewed dishes at a single restaurant location.

Every dish entry in a post requires:

- Restaurant (shared across the post)
- Dish
- At least one rating from 0.5 to 5.0 stars, in half-star increments
- At least one post photo associated with the post

One photo can illustrate several dishes. A photo does not need a one-to-one dish assignment.

Optional fields:

- Short overall caption/review text
- Visit date, including a backdated date
- Optional contextual tags/details, if added later
- Additional photos

A post is displayed as an Instagram-style photo slideshow. Ratings are per dish; there is no required or separate restaurant rating. Users can edit a post. They may modify its restaurant, dish, ratings, photos, caption, and date, provided the post continues to satisfy the required fields. Removing or editing one dish preserves the rest of a multi-dish post. Deleting the entire post removes it and its ratings from aggregates, but does not remove any manually saved collection links.

When a visit date is supplied, display it as the post's date, with no separate “Visited” label. Otherwise display the creation date.

## Ratings and public aggregates

- Rating scale: optional only in the sense that there is no restaurant rating; every reviewed dish must have a 0.5–5.0 star rating.
- Dish pages show their public average rating and recent public activity separately.
- Restaurant pages show a public aggregate across dish ratings plus recent public activity.
- For each user and each dish, public averaging uses that user's most recent remaining eligible rating, preventing frequent visitors from adding extra votes.
- Private-account ratings and private posts are excluded from public averages and public discovery.
- Do not invent a display threshold for averages in v1; product can later add one after observing sparse data behavior.

## Profiles, follow graph, and privacy

Profiles support either public or private visibility.

### Public account

- Anyone can find the account by username and view its eligible posts, ratings, activity, public collections, and rankings.
- Following takes effect immediately.

### Private account

- Following uses an approval-based request. Only approved followers may view its private profile content.
- The owner can view public accounts they follow and private accounts that have approved them.
- Private reviews, photos, collections, ratings, and activity are excluded from public search, Explore, public restaurant activity, and public averages.

Both public and private account owners can remove followers. No blocking or muting is in v1.

Profile pages include:

- An uploaded profile picture, with an initial/avatar fallback when absent.
- Username/profile identity and follower/following counts subject to privacy permissions
- A chronological visual grid of reviews/posts
- Public collections
- Rankings (ranked collections)

Directly below the profile counts, show two icon-only content tabs: a waffle grid for the diary and a bookmark for collections/rankings. Do not show a Photo diary heading. The diary retains its thumbnail grid; tapping a thumbnail opens that post in a vertically scrollable sequence of that author's visible posts. Both owners and authorized viewers can scroll to newer/older entries, with pagination and the existing post actions preserved. The bookmark tab retains collection cards and the owner's create-collection action.

Favorite cuisines, favorite neighborhoods, and a fixed all-time leaderboard are not separate v1 features. A user may make an unrestricted ranked collection to serve as an all-time leaderboard.

## Collections and rankings

Every user begins with a private **Saved Places** collection. It is an ordinary collection that contains locations and supports adding/removing items like any other list.

Users can create other collections as public or private. Collections may contain restaurant locations or links to specific dish-review posts. A linked post item opens that individual post; it is not a generic dish reference.

Collections can be:

- **Unranked**, e.g. “Places to try in Atlanta”
- **Ranked**, e.g. “Top 10 burgers”

Ranked lists have manually controlled, unrestricted positions. A restaurant or post may appear in multiple collections. Rank is independent of star ratings.

## Social interaction

Users who can view a post can like and comment on it.

- A commenter can delete their own comment.
- A post owner can delete any comment on their post.
- Likes and comments trigger push notifications.
- Replies are supported and trigger a push notification.
- Users may tag another user in a post or comment only when both accounts follow each other.

### Direct messages

Messaging is limited to one-to-one conversations between mutual followers. Users can send text and share Plum posts. Photo uploads, group chats, and blocking are out of scope for v1.

The Messages tab lists all mutual approved friends, including friends without an existing conversation. Show their profile pictures and latest message preview. Sort conversations by latest message descending, followed by friends without messages ordered by their most recent mutual follow.

## Discovery

### Home

Home is a chronological feed of visible posts and food logs from accounts the user follows. It has no ranking algorithm in v1.

When a user follows nobody, Home shows a useful starter state with local Atlanta suggestions and accounts to follow.

### Explore

Explore is distinct from Home and contains public material only:

- Free-text search across restaurants, dishes, public users, and public collections
- Exact-name results should be prioritized over looser matches
- Filters for cuisine, neighborhood, and price
- Curated Atlanta collections
- Nearby/local popular places and dishes

Onboarding asks for city or neighborhood, invites a user to log known places and save places they want to try, and allows every step to be skipped. A map is explicitly out of scope for v1.

## iOS navigation and notifications

Use a simple bottom tab bar with icons only:

1. Home — home icon
2. Explore — search icon
3. Create — plus icon
4. Messages — paperplane icon
5. Profile — person icon

The Profile tab has a bell button in its upper-right corner that opens Notifications and a gear button in its upper-left corner that opens Settings. Settings contains Edit profile (including profile photo upload), Enable notifications, and Sign out. The profile body does not show these actions or a Connections & messages button.

Notifications are one chronological row list with actor pictures, readable activity text, and time. Follow request approval/deletion is inline in its notification row; there is no separate Manage follow requests section. Collection rows show numbered restaurant names, including the restaurant and dish summary for a saved tasting, while a saved tasting still opens that individual post.

Push notifications in v1:

- Like on a post
- Comment on a post
- Reply to a comment
- New follower
- Follow request
- Follow-request approval

## Reporting and administration

Users can report posts, accounts, and photos. The first internal moderation console must let admins:

- Triage/process reports
- Remove content
- Merge duplicate restaurant and dish records
- Edit restaurant/dish listings
- Suspend user accounts

When records are merged, preserve existing references by moving linked posts/ratings to the surviving record and retaining alternate names for search. Only admins can directly edit or delete shared restaurant/dish directory records.

## Authentication

Support:

- Sign in with Apple
- Google sign-in
- Email/username/password account flow

The exact recovery and verification design is deferred. Email verification, age gates, and location/privacy consent are not required in v1. Keep authentication provider identities separate from the stable internal user ID.

## Technical recommendation

Build iPhone v1 in Swift/SwiftUI with a backend designed as an API rather than a device-specific implementation.

- **Backend:** Supabase (PostgreSQL, Auth, Storage, Edge Functions) is the preferred starting point because it matches existing familiarity, minimizes launch operations, and offers a clear path to scale.
- **Authorization:** enforce visibility in PostgreSQL row-level security, not only in the app. Private content and aggregate eligibility must be encoded as server-enforced policies.
- **Media:** store original and transformed post/restaurant photos in managed object storage; use signed URLs or permission-aware delivery for private media.
- **Search:** begin with PostgreSQL full-text/trigram search plus normalized aliases and exact-match boosting. Evaluate a dedicated search service only when data/traffic requires it.
- **Maps/places provider:** defer provider selection until comparing Atlanta coverage, pricing, caching/display terms, and the ability to store/place-match user-created locations. Since maps are not in v1, a geocoding/address-validation provider is sufficient initially.
- **Notifications:** use APNs from server-side event handling. Store device tokens per authenticated user and honor platform permission status.
- **Messaging:** model direct messages as a conversation with exactly two members and use realtime subscriptions where appropriate. Server-side membership checks must guard reads and sends.

## High-level data entities

- `users`, `auth_identities`, `profiles`, `device_tokens`
- `follows` (including requested/approved status)
- `restaurants`, `restaurant_aliases`, `dishes`, `dish_aliases`
- `posts`, `post_dishes`, `post_photos`, `photo_dish_links`
- `likes`, `comments`, `comment_mentions`
- `collections`, `collection_items` (restaurant or post reference; optional manual rank)
- `conversations`, `conversation_members`, `messages`, `post_shares`
- `notifications`
- `reports`, `admin_actions`, `record_merge_history`

The `post_dishes` entity owns the rating. It enables individual dish edits/deletion without losing the rest of a multi-dish post. Public aggregate queries should select the most recent eligible `post_dishes` rating for each `(user, dish)` tuple.

## Explicitly out of scope for v1

- Restaurant-wide user reviews/ratings
- Reservations, menus, or delivery ordering
- Maps
- Algorithmic Home ranking
- Android client
- Group DMs and photo attachments in DMs
- Blocking/muting
- User editing of shared directory entries
- Pre-publication moderation of restaurants
- Automatic duplicate merges
- Email verification, age gate, and mandatory consent flow
- Favorite cuisine/neighborhood profile fields

## Open implementation follow-ups

1. Choose the specific place/geocoding provider after a focused commercial and coverage comparison.
2. Define acceptable photo sizes, transformation presets, and retention rules.
3. Specify the recovery path for username/password accounts before production release.
4. Design staff roles, audit logging, and service-level expectations for the moderation console.
5. Establish an initial Atlanta restaurant/dish seeding plan and editorial owners for curated collections.
