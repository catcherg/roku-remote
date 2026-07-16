import SwiftUI

/// Circular remote key with the standard press interaction:
/// scale 0.94 + brighter fill, 120ms ease-out (roadmap Phase 3 task 2).
struct RemoteKeyStyle: ButtonStyle {
    var diameter: CGFloat = 56
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.medium))
            .foregroundStyle(prominent ? Color.black : Color.primary)
            .frame(width: diameter, height: diameter)
            .background(
                Circle().fill(
                    prominent
                    ? AnyShapeStyle(Theme.accent)
                    : AnyShapeStyle(configuration.isPressed ? Theme.keyPressed : Theme.keyFill)
                )
            )
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(Theme.pressAnimation, value: configuration.isPressed)
    }
}

/// Capsule action button (keyboard / channels quick actions).
struct CapsuleActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .frame(height: Theme.minTarget)
            .background(
                Capsule().fill(configuration.isPressed ? Theme.keyPressed : Theme.keyFill)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.pressAnimation, value: configuration.isPressed)
    }
}

/// Skeleton shimmer for loading placeholders (Phase 3 task 4).
/// Respects Reduce Motion by falling back to a static placeholder.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.55)
        } else {
            content
                .overlay(
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.12), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width * 1.6)
                    }
                    .allowsHitTesting(false)
                )
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
