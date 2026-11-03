import SwiftUI
import PlumDomain

/// The chronological feed for people you follow. The data source can be swapped for
/// a store later; keeping the display fixtures here makes the first-run experience
/// and previews useful while the app is offline.
struct HomeView: View {
    @State private var showsEmptyState = false
    @State private var likedPostIDs: Set<UUID> = []

    private let posts = HomeFeedFixture.posts

    var body: some View {
        NavigationStack {
            Group {
                if showsEmptyState {
                    EmptyFollowingView()
                } else {
                    feed
                }
            }
            .background(HomePalette.cream.ignoresSafeArea())
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Show starter state", isOn: $showsEmptyState)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .fontWeight(.semibold)
                            .accessibilityLabel("Feed options")
                    }
                    .tint(HomePalette.plum)
                }
            }
        }
        .tint(HomePalette.plum)
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                FeedWelcome()

                ForEach(posts) { post in
                    FeedPostCard(
                        post: post,
                        isLiked: likedPostIDs.contains(post.id),
                        onLike: { toggleLike(for: post.id) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func toggleLike(for id: UUID) {
        if likedPostIDs.contains(id) {
            likedPostIDs.remove(id)
        } else {
            likedPostIDs.insert(id)
        }
    }
}

private struct FeedWelcome: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(HomePalette.plum)
                .frame(width: 42, height: 42)
                .background(HomePalette.blush, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Fresh from your table")
                    .font(.subheadline.weight(.bold))
                Text("The latest bites from people you follow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FeedPostCard: View {
    let post: FeedPost
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(post.author.initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(post.author.avatarColor, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author.name)
                        .font(.subheadline.weight(.bold))
                    Text("@\(post.author.handle) · \(post.relativeDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .accessibilityLabel("More options")
            }
            .padding([.horizontal, .top], 14)
            .padding(.bottom, 12)

            FeedPhoto(url: post.photoURL, fallback: post.photoFallback)
                .frame(height: 248)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(post.restaurant)
                            .font(.headline)
                        Text("\(post.neighborhood) · \(post.cuisine)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    RatingBadge(rating: post.rating)
                }

                Text(post.dish)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomePalette.plum)

                Text(post.caption)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 20) {
                    Button(action: onLike) {
                        Label("\(post.likeCount + (isLiked ? 1 : 0))", systemImage: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? HomePalette.berry : HomePalette.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isLiked ? "Unlike post" : "Like post")

                    Button {} label: {
                        Label("\(post.commentCount)", systemImage: "bubble.right")
                            .foregroundStyle(HomePalette.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(post.commentCount) comments")

                    Spacer()

                    Button {} label: {
                        Image(systemName: "bookmark")
                            .foregroundStyle(HomePalette.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save post")
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(14)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HomePalette.plum.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: HomePalette.plum.opacity(0.08), radius: 14, y: 6)
    }
}

private struct FeedPhoto: View {
    let url: URL
    let fallback: [Color]

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                LinearGradient(colors: fallback, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.85))
                    }
            }
        }
        .accessibilityLabel("Photo of food at a restaurant")
    }
}

private struct RatingBadge: View {
    let rating: Double

    var body: some View {
        VStack(spacing: 1) {
            Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(HomePalette.plum)
            Text("out of 5")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(HomePalette.gold.opacity(0.34), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(rating.formatted(.number.precision(.fractionLength(1)))) out of 5")
    }
}

private struct EmptyFollowingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(HomePalette.plum)
                    .frame(width: 100, height: 100)
                    .background(HomePalette.blush, in: Circle())
                    .padding(.top, 42)

                VStack(spacing: 8) {
                    Text("Your table is waiting")
                        .font(.title2.weight(.bold))
                    Text("Follow fellow eaters to fill this feed with the places and dishes worth talking about.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Atlanta food people to follow")
                        .font(.headline)
                    ForEach(HomeFeedFixture.suggestions) { person in
                        SuggestionRow(person: person)
                    }
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
    }
}

private struct SuggestionRow: View {
    let person: SuggestedPerson
    @State private var isFollowing = false

    var body: some View {
        HStack(spacing: 10) {
            Text(person.initials)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(person.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.subheadline.weight(.semibold))
                Text(person.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(isFollowing ? "Following" : "Follow") { isFollowing.toggle() }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isFollowing ? HomePalette.plum : .white)
                .background(isFollowing ? HomePalette.blush : HomePalette.plum, in: Capsule())
        }
    }
}

private struct FeedPost: Identifiable {
    let id = UUID()
    let author: FeedAuthor
    let restaurant: String
    let neighborhood: String
    let cuisine: String
    let dish: String
    let rating: Double
    let caption: String
    let photoURL: URL
    let photoFallback: [Color]
    let relativeDate: String
    let likeCount: Int
    let commentCount: Int
}

private struct FeedAuthor {
    let name: String
    let handle: String
    let initials: String
    let avatarColor: Color
}

private struct SuggestedPerson: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let detail: String
    let color: Color
}

private enum HomeFeedFixture {
    // SampleData remains the canonical simple fixture for the domain package;
    // the richer local fixtures below supply presentation-only people and context.
    static let sampleRestaurantName = SampleData.restaurant.name

    static let posts: [FeedPost] = [
        FeedPost(author: FeedAuthor(name: "Maya Chen", handle: "mayaeats", initials: "MC", avatarColor: .orange), restaurant: sampleRestaurantName, neighborhood: "Inman Park", cuisine: "Italian", dish: "Black spaghetti", rating: 4.5, caption: "Silky, inky, a little spicy — and absolutely worth getting the extra bread for.", photoURL: URL(string: "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1200&q=85")!, photoFallback: [.purple, .orange], relativeDate: "2h", likeCount: 38, commentCount: 6),
        FeedPost(author: FeedAuthor(name: "Jordan Reed", handle: "jrdoesdinner", initials: "JR", avatarColor: .teal), restaurant: "Kimball House", neighborhood: "Decatur", cuisine: "Seafood", dish: "Roasted oysters", rating: 5.0, caption: "A perfect slow Sunday: briny oysters, a chilled red, and no plans after this.", photoURL: URL(string: "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=85")!, photoFallback: [.blue, .mint], relativeDate: "Yesterday", likeCount: 64, commentCount: 12),
        FeedPost(author: FeedAuthor(name: "Nia Brooks", handle: "niaknowsatl", initials: "NB", avatarColor: .pink), restaurant: "Little Bear", neighborhood: "Summerhill", cuisine: "New American", dish: "Corn agnolotti", rating: 4.0, caption: "The brown butter situation deserves its own fan club. Save room for dessert.", photoURL: URL(string: "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=1200&q=85")!, photoFallback: [.yellow, .red], relativeDate: "Mon", likeCount: 27, commentCount: 4)
    ]

    static let suggestions: [SuggestedPerson] = [
        SuggestedPerson(name: "Avery Thompson", initials: "AT", detail: "Old Fourth Ward · 42 places saved", color: .indigo),
        SuggestedPerson(name: "Priya Shah", initials: "PS", detail: "Buford Highway regular", color: .brown),
        SuggestedPerson(name: "Leo Martinez", initials: "LM", detail: "Westside · Pasta enthusiast", color: .green)
    ]
}

private enum HomePalette {
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.89)
    static let plum = Color(red: 0.35, green: 0.08, blue: 0.24)
    static let berry = Color(red: 0.69, green: 0.16, blue: 0.31)
    static let blush = Color(red: 0.94, green: 0.84, blue: 0.85)
    static let gold = Color(red: 0.95, green: 0.76, blue: 0.32)
    static let ink = Color(red: 0.15, green: 0.10, blue: 0.13)
}

#Preview("Following") {
    HomeView()
}
