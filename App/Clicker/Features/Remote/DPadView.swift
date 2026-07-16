import SwiftUI
import RokuKit

/// Large circular d-pad (Phase 3 task 2): four annular-wedge buttons around a
/// prominent OK. Radial gradient gives the ring a subtle concave affordance.
struct DPadView: View {
    @EnvironmentObject private var app: AppState

    var size: CGFloat = 272
    private var innerRatio: CGFloat { 0.38 }

    var body: some View {
        ZStack {
            // Ring base with concave affordance: slightly darker toward center.
            Circle()
                .fill(Theme.surface)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
                .allowsHitTesting(false)

            wedge(.up, symbol: "chevron.up", label: "Directional pad, up",
                  start: -135, end: -45)
            wedge(.right, symbol: "chevron.forward", label: "Directional pad, right",
                  start: -45, end: 45)
            wedge(.down, symbol: "chevron.down", label: "Directional pad, down",
                  start: 45, end: 135)
            wedge(.left, symbol: "chevron.backward", label: "Directional pad, left",
                  start: 135, end: 225)

            Button {
                Haptics.medium()
                app.send(.select)
            } label: {
                Text("OK")
            }
            .buttonStyle(RemoteKeyStyle(diameter: size * innerRatio * 0.92, prominent: true))
            .accessibilityLabel("Select")
        }
        .frame(width: size, height: size)
    }

    private func wedge(_ key: ECPKey, symbol: String, label: String,
                       start: Double, end: Double) -> some View {
        let shape = AnnularWedge(
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            innerRatio: innerRatio
        )
        let mid = Angle.degrees((start + end) / 2).radians
        let iconRadius = size * 0.345

        return Button {
            Haptics.light()
            app.send(key)
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .offset(x: cos(mid) * iconRadius, y: sin(mid) * iconRadius)
                .frame(width: size, height: size)
        }
        .buttonStyle(WedgeStyle(shape: shape))
        .contentShape(shape)
        .accessibilityLabel(label)
    }
}

/// Annular sector between two angles — the tappable quarter of the d-pad ring.
struct AnnularWedge: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        var path = Path()
        path.addArc(center: center, radius: outerRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// Press feedback for a wedge: brighter fill clipped to the wedge shape.
struct WedgeStyle: ButtonStyle {
    let shape: AnnularWedge

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                shape.fill(configuration.isPressed ? Theme.keyPressed : Color.clear)
            )
            .animation(Theme.pressAnimation, value: configuration.isPressed)
    }
}
