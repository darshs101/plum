import SwiftUI

enum PlumStyle {
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.89)
    static let plum = Color.plum
    static let cornerRadius: CGFloat = 16

    enum Motion {
        static let entrance = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
        static let entranceStagger = 0.05
        static let entranceOffset: CGFloat = 8
    }
}

/// Used for infrequent actions. Routine rows and tab switches retain native,
/// immediate feedback. `isStatic` lets a surface opt out of scale feedback.
struct PlumActionStyle: ButtonStyle {
    enum Emphasis { case primary, secondary }
    var emphasis: Emphasis = .primary
    var isStatic = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(emphasis == .primary ? Color.white : Color.plum)
            .background(emphasis == .primary ? Color.plum : Color.plum.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(!isEnabled ? 0.45 : pressed ? 0.8 : 1)
            .scaleEffect(pressed && !reduceMotion && !isStatic ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: pressed)
    }
}

private struct PlumPhotoEdge: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    func body(content: Content) -> some View {
        let pixel = 1 / displayScale
        content.overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .inset(by: pixel)
                .strokeBorder((colorScheme == .dark ? Color.white : Color.black).opacity(0.1), lineWidth: pixel)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func plumPhotoEdge(radius: CGFloat = 0) -> some View { modifier(PlumPhotoEdge(radius: radius)) }
}
