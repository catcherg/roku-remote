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
    /// True while a finger is down. Gesture state resets when the touch ends
    /// *or is cancelled* (a sheet opens, a call comes in, the app goes to the
    /// background), so the key-up below goes out either way. `onEnded` alone
    /// is not called for a cancelled touch, which would leave the Roku
    /// ramping the volume with nothing to stop it.
    @GestureState private var isTouching = false
    /// True between the key-down the Roku was sent and its key-up.
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
                    .updating($isTouching) { _, touching, _ in touching = true }
            )
            .onChange(of: isTouching) { touching in
                if touching { beginHold() } else { endHold() }
            }
            .onDisappear(perform: endHold)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }

    private func beginHold() {
        // Refused when the free key presses are used up: nothing was sent,
        // so there is nothing to tick for and nothing to release.
        guard !isHolding, app.beginHold(key) else { return }
        isHolding = true
        Haptics.light()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            Haptics.light()
        }
    }

    private func endHold() {
        guard isHolding else { return }
        isHolding = false
        tickTimer?.invalidate()
        tickTimer = nil
        app.endHold(key)
    }
}
