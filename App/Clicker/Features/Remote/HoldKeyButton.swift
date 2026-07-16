import SwiftUI
import RokuKit

/// Press-and-hold key for volume ramping (Phase 3 task 3): sends `keydown` on
/// touch, `keyup` on release — the Roku auto-repeats while held — with
/// repeating light haptic ticks so the ramp is felt in the hand.
struct HoldKeyButton: View {
    let key: ECPKey
    let symbol: String
    let label: String

    @EnvironmentObject private var app: AppState
    @State private var isHolding = false
    @State private var tickTimer: Timer?

    var body: some View {
        Image(systemName: symbol)
            .font(.title3.weight(.medium))
            .frame(width: 56, height: 56)
            .background(Circle().fill(isHolding ? Theme.keyPressed : Theme.keyFill))
            .brightness(isHolding ? 0.08 : 0)
            .scaleEffect(isHolding ? 0.94 : 1)
            .animation(Theme.pressAnimation, value: isHolding)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isHolding else { return }
                        isHolding = true
                        Haptics.light()
                        app.beginHold(key)
                        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                            Haptics.light()
                        }
                    }
                    .onEnded { _ in
                        isHolding = false
                        tickTimer?.invalidate()
                        tickTimer = nil
                        app.endHold(key)
                    }
            )
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }
}
