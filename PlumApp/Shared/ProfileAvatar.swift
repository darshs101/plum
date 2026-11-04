import SwiftUI

struct ProfileAvatar: View {
    let path: String?
    var name = ""
    var size: CGFloat = 48
    @State private var url: URL?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else {
                Circle().fill(Color.plum.opacity(0.1)).overlay {
                    if let initial = name.first { Text(String(initial).uppercased()).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(.plum) }
                    else { Image(systemName: "person").font(.system(size: size * 0.4)).foregroundStyle(.plum) }
                }
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .overlay { Circle().strokeBorder((colorScheme == .dark ? Color.white : .black).opacity(0.1), lineWidth: 1 / displayScale).allowsHitTesting(false) }
        .accessibilityHidden(true)
        .task(id: path) {
            url = nil
            guard let path, let client = PlumServices.client else { return }
            url = try? await client.storage.from("profile-media").createSignedURL(path: path, expiresIn: 300)
        }
    }
}
