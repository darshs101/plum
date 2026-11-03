import SwiftUI

struct ProfileView: View {
    @State private var showingNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    profileHeader
                    activityStrip
                    photoDiary
                    collectionsSection
                    rankedSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
            .background(PlumStyle.cream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNotifications = true } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.plum)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.65), in: Circle())
                            .overlay(alignment: .topTrailing) { Circle().fill(.red).frame(width: 7, height: 7).padding(7) }
                    }
                    .accessibilityLabel("Notifications")
                }
            }
            .sheet(isPresented: $showingNotifications) { NotificationView() }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.plum, .purple.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 86, height: 86)
                Text("DS").font(.system(size: 27, weight: .medium, design: .serif)).foregroundStyle(PlumStyle.cream)
            }
            VStack(spacing: 4) {
                Text("Darsh Shetty").font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(.plum)
                Text("@darshdines · Atlanta, GA").font(.subheadline).foregroundStyle(.plum.opacity(0.62))
            }
            Text("A running list of plates worth going back for.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.plum.opacity(0.77))
            HStack(spacing: 0) {
                stat("47", "posts"); divider; stat("18", "collections"); divider; stat("326", "followers")
            }
            .padding(.top, 3)
        }
    }

    private func stat(_ number: String, _ label: String) -> some View {
        VStack(spacing: 2) { Text(number).font(.headline).foregroundStyle(.plum); Text(label).font(.caption).foregroundStyle(.plum.opacity(0.58)) }
            .frame(maxWidth: .infinity)
    }
    private var divider: some View { Rectangle().fill(.plum.opacity(0.14)).frame(width: 1, height: 24) }

    private var activityStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").font(.subheadline.weight(.semibold)).foregroundStyle(.plum)
            Text("Last bite: **mushroom agnolotti** at BoccaLupo")
                .font(.subheadline).foregroundStyle(.plum.opacity(0.8))
            Spacer()
        }
        .padding(13)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var photoDiary: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("PHOTO DIARY", detail: "Newest first")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(ProfilePhoto.samples) { photo in
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(photo.gradient)
                        Image(systemName: photo.symbol).font(.title2).foregroundStyle(.white.opacity(0.8)).frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text(photo.month).font(.caption2.weight(.bold)).foregroundStyle(.white).padding(6)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("PUBLIC COLLECTIONS", detail: "See all")
            ForEach(ProfileCollection.publicCollections) { collection in CollectionRow(collection: collection) }
        }
    }

    private var rankedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("RANKED, NO NOTES", detail: "Personal canon")
            ForEach(ProfileCollection.rankedCollections) { collection in
                HStack(spacing: 13) {
                    Text(collection.rank).font(.system(size: 24, weight: .medium, design: .serif)).foregroundStyle(.plum.opacity(0.5)).frame(width: 25)
                    VStack(alignment: .leading, spacing: 3) { Text(collection.title).font(.headline).foregroundStyle(.plum); Text(collection.subtitle).font(.caption).foregroundStyle(.plum.opacity(0.62)) }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.plum.opacity(0.35))
                }
                .padding(.vertical, 7)
            }
        }
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack { Text(title).font(.caption2.weight(.bold)).tracking(1.35).foregroundStyle(.plum.opacity(0.68)); Spacer(); Text(detail).font(.caption.weight(.medium)).foregroundStyle(.plum.opacity(0.55)) }
    }
}

private struct CollectionRow: View {
    let collection: ProfileCollection
    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(collection.gradient).frame(width: 62, height: 62)
                .overlay(Image(systemName: collection.symbol).foregroundStyle(.white.opacity(0.86)).font(.title3))
            VStack(alignment: .leading, spacing: 4) { Text(collection.title).font(.headline).foregroundStyle(.plum); Text(collection.subtitle).font(.caption).foregroundStyle(.plum.opacity(0.62)) }
            Spacer(); Text(collection.count).font(.caption.weight(.bold)).foregroundStyle(.plum.opacity(0.58))
        }
        .padding(9)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NotificationView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("TODAY") {
                    notification("Maya added a place", "Kimball House joined her ‘Date Night’ list.", "heart.fill")
                    notification("Your list is trending", "‘Atlanta After Dark’ has 24 new saves.", "arrow.up.right")
                }
                Section("THIS WEEK") { notification("Miles followed you", "See what he has been eating lately.", "person.badge.plus") }
            }
            .scrollContentBackground(.hidden).background(PlumStyle.cream)
            .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(.plum) } }
        }
    }
    private func notification(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 12) { Image(systemName: symbol).foregroundStyle(.plum).frame(width: 28); VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline.weight(.semibold)); Text(detail).font(.caption).foregroundStyle(.secondary) } }
            .listRowBackground(Color.white.opacity(0.55))
    }
}

private struct ProfilePhoto: Identifiable {
    let id = UUID(); let month, symbol: String; let gradient: LinearGradient
    static let samples: [ProfilePhoto] = [
        .init(month: "NOV", symbol: "fork.knife", gradient: .init(colors: [.orange, .brown], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "NOV", symbol: "wineglass.fill", gradient: .init(colors: [.plum, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "OCT", symbol: "leaf.fill", gradient: .init(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "OCT", symbol: "birthday.cake.fill", gradient: .init(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "OCT", symbol: "cup.and.saucer.fill", gradient: .init(colors: [.brown, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "SEP", symbol: "flame.fill", gradient: .init(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "SEP", symbol: "fish.fill", gradient: .init(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "AUG", symbol: "carrot.fill", gradient: .init(colors: [.green, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(month: "AUG", symbol: "sparkles", gradient: .init(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
    ]
}

private struct ProfileCollection: Identifiable {
    let id = UUID(); let title, subtitle, count, symbol, rank: String; let gradient: LinearGradient
    static let publicCollections: [ProfileCollection] = [
        .init(title: "Out-of-Towners, Start Here", subtitle: "The essential Atlanta weekend", count: "14", symbol: "suitcase.fill", rank: "", gradient: .init(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)),
        .init(title: "Tiny Tables, Big Mood", subtitle: "Intimate dinners I’d repeat", count: "8", symbol: "candle.fill", rank: "", gradient: .init(colors: [.plum, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
    ]
    static let rankedCollections: [ProfileCollection] = [
        .init(title: "Atlanta pasta", subtitle: "My ongoing top five", count: "", symbol: "", rank: "01", gradient: .init(colors: [], startPoint: .top, endPoint: .bottom)),
        .init(title: "A proper bar seat", subtitle: "Solo dinner supremacy", count: "", symbol: "", rank: "02", gradient: .init(colors: [], startPoint: .top, endPoint: .bottom)),
        .init(title: "The crispy things", subtitle: "Fries, chicken, skin, edges", count: "", symbol: "", rank: "03", gradient: .init(colors: [], startPoint: .top, endPoint: .bottom))
    ]
}
