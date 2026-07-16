import SwiftUI
import UIKit
import RokuKit

/// Eyes-free remote (UI overhaul spec). The user is looking at the TV, not the
/// phone: a massive swipe surface dominates the upper half — swipe to navigate
/// (velocity-scaled, strictly 4-directional), tap anywhere to Select — with a
/// high-contrast utility grid below. Haptics are the primary feedback channel:
/// one crisp light tick per swipe/tap, a heavier thud for OK and Back.
/// All commands route through AppState → RokuKit's ECPClient.
struct RemoteControlView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var haptics = HapticEngine()
    @State private var showKeyboard = false
    @State private var showChannels = false
    @State private var showLimitedHelp = false

    private var isTV: Bool { app.device?.isTV ?? false }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 20) {
                SwipeSurface(
                    onSwipe: { direction, repeats in swipe(direction, repeats: repeats) },
                    onSelect: select
                )
                .frame(height: max(proxy.size.height * 0.52, 280))

                utilityGrid

                if isTV {
                    volumeRow
                }

                quickActions

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    haptics.tick()
                    app.disconnect()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("Back to devices")
            }
            ToolbarItem(placement: .principal) {
                StatusPill()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isTV {
                    Button {
                        haptics.thud(.rigid)
                        app.send(.power)
                    } label: {
                        Image(systemName: "power")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Power")
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if app.isReconnecting {
                Text("Reconnecting…")
                    .font(.footnote.weight(.medium))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(.yellow.opacity(0.25))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.isReconnecting)
        .sheet(isPresented: $showKeyboard) {
            KeyboardSheet()
                .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $showChannels) {
            ChannelGridView()
        }
        .alert("Roku is blocking control", isPresented: $app.limitedModeDetected) {
            Button("Show me the fix") { showLimitedHelp = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Roku's \"Control by mobile apps\" setting is set to Limited. See Help for the 30-second fix.")
        }
        .sheet(isPresented: $showLimitedHelp) {
            NavigationStack { HelpView() }
        }
    }

    // MARK: - Actions (all through the existing command layer)

    private func swipe(_ direction: SwipeDirection, repeats: Int) {
        haptics.tick() // exactly one crisp event per swipe, even when it repeats
        Task {
            for index in 0..<repeats {
                app.send(direction.key)
                if index < repeats - 1 {
                    try? await Task.sleep(nanoseconds: 60_000_000)
                }
            }
        }
    }

    private func select() {
        haptics.thud(.medium)
        app.send(.select)
    }

    // MARK: - Utility grid (Back / Home / Play-Pause / Mute-or-Replay)

    private var utilityGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            spacing: 16
        ) {
            gridKey(.back, "arrow.backward", "Back") {
                haptics.thud(.medium) // Back gets the heavier thud per spec;
                app.send(.back)       // it never shows a confirmation dialog.
            }
            gridKey(.home, "house.fill", "Home") {
                haptics.tick()
                app.send(.home)
            }
            gridKey(.play, "playpause.fill", "Play or pause") {
                haptics.tick()
                app.send(.play)
            }
            if isTV {
                gridKey(.volumeMute, "speaker.slash.fill", "Mute") {
                    haptics.tick()
                    app.send(.volumeMute)
                }
            } else {
                // Sticks can't mute a TV over ECP (CLAUDE.md: volume keys are
                // TV-only) — no dead buttons; Instant Replay earns the slot.
                gridKey(.instantReplay, "arrow.uturn.backward", "Instant replay") {
                    haptics.tick()
                    app.send(.instantReplay)
                }
            }
        }
    }

    private func gridKey(_ key: ECPKey, _ symbol: String, _ label: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(GridKeyStyle())
        .accessibilityLabel(label)
    }

    private var volumeRow: some View {
        HStack(spacing: 16) {
            HoldKeyButton(key: .volumeDown, symbol: "speaker.minus.fill",
                          label: "Volume down, hold to ramp")
            HoldKeyButton(key: .volumeUp, symbol: "speaker.plus.fill",
                          label: "Volume up, hold to ramp")
        }
    }

    private var quickActions: some View {
        HStack(spacing: 14) {
            Button {
                haptics.tick()
                showKeyboard = true
            } label: {
                Label("Keyboard", systemImage: "keyboard")
            }
            .buttonStyle(CapsuleActionStyle())

            Button {
                haptics.tick()
                showChannels = true
            } label: {
                Label("Channels", systemImage: "square.grid.3x3")
            }
            .buttonStyle(CapsuleActionStyle())

            Button {
                haptics.tick()
                app.send(.search)
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(CapsuleActionStyle())
        }
    }
}

// MARK: - Swipe surface

/// Strictly 4-directional (no diagonals): the dominant axis must beat the other
/// by 20% or the gesture is ignored as ambiguous. A near-stationary touch is a
/// tap = Select. Repeat count scales with swipe velocity (1–4 presses).
private struct SwipeSurface: View {
    let onSwipe: (SwipeDirection, Int) -> Void
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash: SwipeDirection?
    @State private var selectPulse = false

    private let tapThreshold: CGFloat = 20
    private let dominanceRatio: CGFloat = 1.2

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Theme.surface)
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(colors: [Color.black.opacity(0.25), .clear],
                                   center: .center, startRadius: 0, endRadius: 320)
                )
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)

            // Faint affordances — visible if you glance, ignorable if you don't.
            directionHints
            Circle()
                .strokeBorder(Color.white.opacity(selectPulse ? 0.5 : 0.12), lineWidth: 1.5)
                .frame(width: 72, height: 72)
            Text("OK")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(selectPulse ? 0.8 : 0.25))

            // Visual echo of the last swipe (secondary to the haptic).
            if let flash {
                Image(systemName: flash.symbol)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .offset(flash.echoOffset)
                    .transition(.opacity)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28))
        .gesture(dragOrTap)
        .accessibilityElement()
        .accessibilityLabel("Touch surface")
        .accessibilityHint("Swipe up, down, left, or right to navigate. Double-tap to select.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire(nil) }
        .accessibilityAction(named: "Up") { fire(.up) }
        .accessibilityAction(named: "Down") { fire(.down) }
        .accessibilityAction(named: "Left") { fire(.left) }
        .accessibilityAction(named: "Right") { fire(.right) }
    }

    private var dragOrTap: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let distance = hypot(dx, dy)

                if distance < tapThreshold {
                    fire(nil)
                    return
                }
                // Dominant axis only — diagonals are ignored, never guessed.
                let direction: SwipeDirection
                if abs(dx) > abs(dy) * dominanceRatio {
                    direction = dx > 0 ? .right : .left
                } else if abs(dy) > abs(dx) * dominanceRatio {
                    direction = dy > 0 ? .down : .up
                } else {
                    return
                }
                // Velocity scaling: a flick travels further than a nudge.
                let predicted = hypot(value.predictedEndTranslation.width - dx,
                                      value.predictedEndTranslation.height - dy)
                let repeats = 1 + min(3, Int(predicted / 220))
                fire(direction, repeats: repeats)
            }
    }

    private func fire(_ direction: SwipeDirection?, repeats: Int = 1) {
        if let direction {
            onSwipe(direction, repeats)
            guard !reduceMotion else { return }
            flash = direction
            withAnimation(.easeOut(duration: 0.15)) {}
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.easeOut(duration: 0.2)) { flash = nil }
            }
        } else {
            onSelect()
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.1)) { selectPulse = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                withAnimation(.easeOut(duration: 0.25)) { selectPulse = false }
            }
        }
    }

    private var directionHints: some View {
        VStack {
            Image(systemName: "chevron.up")
            Spacer()
            HStack {
                Image(systemName: "chevron.left")
                Spacer()
                Image(systemName: "chevron.right")
            }
            Spacer()
            Image(systemName: "chevron.down")
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(Color.white.opacity(0.18))
        .padding(18)
        .allowsHitTesting(false)
    }
}

private enum SwipeDirection: Equatable {
    case up, down, left, right

    var key: ECPKey {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }

    var symbol: String {
        switch self {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        }
    }

    var echoOffset: CGSize {
        switch self {
        case .up: return CGSize(width: 0, height: -90)
        case .down: return CGSize(width: 0, height: 90)
        case .left: return CGSize(width: -110, height: 0)
        case .right: return CGSize(width: 110, height: 0)
        }
    }
}

// MARK: - Haptics (prepared generators, one event per action)

/// Prepared UIImpactFeedbackGenerators for crisp, low-latency feedback.
/// Re-prepares after each fire so the Taptic Engine stays warm. Respects the
/// user's Haptics toggle in Settings ("hapticsEnabled").
@MainActor
final class HapticEngine: ObservableObject {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    init() {
        light.prepare()
        medium.prepare()
        rigid.prepare()
    }

    /// Light, crisp tick — every directional swipe or standard tap.
    func tick() {
        guard isEnabled else { return }
        light.impactOccurred()
        light.prepare()
    }

    /// Heavier transient thud — OK/Select, Back, Power.
    func thud(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        switch style {
        case .rigid:
            rigid.impactOccurred()
            rigid.prepare()
        default:
            medium.impactOccurred()
            medium.prepare()
        }
    }
}

// MARK: - Grid key style (high-contrast, equal spacing, oversized targets)

private struct GridKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(configuration.isPressed ? Theme.keyPressed : Theme.keyFill)
            )
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.pressAnimation, value: configuration.isPressed)
    }
}
