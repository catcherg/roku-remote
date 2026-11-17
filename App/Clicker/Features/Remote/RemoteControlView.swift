import SwiftUI
import UIKit
import RokuKit

/// Eyes-free remote. A large swipe surface dominates the top half — swipe to
/// navigate (velocity-scaled, strictly 4-directional), tap anywhere to Select —
/// with a flexible utility grid filling the rest of the screen. Haptics are the
/// primary feedback channel; the visual layer is a direction-aware gradient
/// sweep that never competes with the TV for attention.
/// All commands route through AppState → RokuKit's ECPClient.
struct RemoteControlView: View {
    /// The one sheet on screen at a time. A single slot, so the paywall can
    /// take over from the keyboard or the channel list when a key press is
    /// refused there.
    private enum RemoteSheet: Identifiable {
        case keyboard, channels, limitedHelp, paywall
        var id: Self { self }
    }

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var entitlements: EntitlementStore
    @StateObject private var haptics = HapticEngine()
    @State private var sheet: RemoteSheet?

    private var isTV: Bool { app.device?.isTV ?? false }

    var body: some View {
        GeometryReader { proxy in
            // The first arrangement whose controls all fit the screen height
            // wins: roomy on tall phones, tighter on small ones, so the
            // bottom row is never pushed off screen.
            ViewThatFits(in: .vertical) {
                controls(height: proxy.size.height, metrics: .regular)
                controls(height: proxy.size.height, metrics: .compact)
                controls(height: proxy.size.height, metrics: .tight)
            }
            // The keys are glyphs in fixed-size shapes. Past this size the
            // glyphs outgrow them (the volume symbols collide), so the
            // remote stops scaling here; every other screen scales fully.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .keyboard:
                KeyboardSheet()
                    .presentationDetents([.height(220)])
            case .channels:
                ChannelGridView()
            case .limitedHelp:
                NavigationStack { HelpView() }
            case .paywall:
                NavigationStack { PaywallView() }
            }
        }
        // A key press was refused: the free presses are used up and no plan
        // is owned. Show the plans in place of whatever sheet was open.
        .onChange(of: entitlements.paywallRequested) { requested in
            if requested {
                sheet = .paywall
                entitlements.paywallRequested = false
            }
        }
        .alert("Roku is blocking control", isPresented: $app.limitedModeDetected) {
            Button("Show me the fix") { sheet = .limitedHelp }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Roku's \"Control by mobile apps\" setting is set to Limited. See Help for the 30-second fix.")
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

    // MARK: - Controls

    /// The whole remote at one set of sizes: swipe surface, key grid, then
    /// the quick actions.
    private func controls(height: CGFloat, metrics: RemoteMetrics) -> some View {
        VStack(spacing: metrics.sectionSpacing) {
            SwipeSurface(
                onSwipe: { direction, repeats in swipe(direction, repeats: repeats) },
                onSelect: select
            )
            .frame(height: max(height * metrics.surfaceShare, metrics.surfaceMinHeight))

            // Flexible control area: absorbs all remaining height so there
            // is no dead space on tall phones.
            VStack(spacing: metrics.keySpacing) {
                HStack(spacing: metrics.keySpacing) {
                    gridKey(.back, "arrow.backward", "Back", minHeight: metrics.keyMinHeight) {
                        haptics.thud(.medium) // heavier thud; never a dialog
                        app.send(.back)
                    }
                    gridKey(.home, "house.fill", "Home", minHeight: metrics.keyMinHeight) {
                        haptics.tick()
                        app.send(.home)
                    }
                }
                HStack(spacing: metrics.keySpacing) {
                    gridKey(.play, "playpause.fill", "Play or pause", minHeight: metrics.keyMinHeight) {
                        haptics.tick()
                        app.send(.play)
                    }
                    if isTV {
                        gridKey(.volumeMute, "speaker.slash.fill", "Mute", minHeight: metrics.keyMinHeight) {
                            haptics.tick()
                            app.send(.volumeMute)
                        }
                    } else {
                        // Sticks can't mute a TV over ECP (CLAUDE.md:
                        // volume keys are TV-only) — no dead buttons.
                        gridKey(.instantReplay, "arrow.uturn.backward", "Instant replay",
                                minHeight: metrics.keyMinHeight) {
                            haptics.tick()
                            app.send(.instantReplay)
                        }
                    }
                }
                if isTV {
                    HStack(spacing: metrics.keySpacing) {
                        HoldKeyButton(key: .volumeDown, symbol: "speaker.minus.fill",
                                      label: "Volume down, hold to ramp")
                        HoldKeyButton(key: .volumeUp, symbol: "speaker.plus.fill",
                                      label: "Volume up, hold to ramp")
                    }
                }
            }
            .frame(maxHeight: .infinity)

            quickActions
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func gridKey(_ key: ECPKey, _ symbol: String, _ label: String, minHeight: CGFloat,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: minHeight, maxHeight: 96)
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(GridKeyStyle())
        .accessibilityLabel(label)
    }

    /// Keyboard, Channels, Search. Each label stays on one line: full-size
    /// text where the row is wide enough, smaller text on narrow phones, and
    /// icons alone at the largest text sizes.
    private var quickActions: some View {
        ViewThatFits(in: .horizontal) {
            quickActionRow(font: .subheadline.weight(.semibold), padding: 12, spacing: 10, showsTitles: true)
            quickActionRow(font: .caption.weight(.semibold), padding: 8, spacing: 8, showsTitles: true)
            quickActionRow(font: .subheadline.weight(.semibold), padding: 12, spacing: 10, showsTitles: false)
        }
    }

    private func quickActionRow(font: Font, padding: CGFloat, spacing: CGFloat,
                                showsTitles: Bool) -> some View {
        let style = CapsuleActionStyle(font: font, horizontalPadding: padding, fillsWidth: true)
        return HStack(spacing: spacing) {
            Button {
                haptics.tick()
                sheet = .keyboard
            } label: {
                quickActionLabel("Keyboard", "keyboard", showsTitle: showsTitles)
            }
            .buttonStyle(style)

            Button {
                haptics.tick()
                sheet = .channels
            } label: {
                quickActionLabel("Channels", "square.grid.3x3", showsTitle: showsTitles)
            }
            .buttonStyle(style)

            Button {
                haptics.tick()
                app.send(.search)
            } label: {
                quickActionLabel("Search", "magnifyingglass", showsTitle: showsTitles)
            }
            .buttonStyle(style)
        }
    }

    /// Icon-only labels keep their title for VoiceOver.
    @ViewBuilder
    private func quickActionLabel(_ title: String, _ symbol: String, showsTitle: Bool) -> some View {
        if showsTitle {
            Label(title, systemImage: symbol)
        } else {
            Label(title, systemImage: symbol).labelStyle(.iconOnly)
        }
    }
}

/// Sizes for one arrangement of the remote, from roomy to tight.
private struct RemoteMetrics {
    /// Share of the available height given to the swipe surface.
    var surfaceShare: CGFloat
    var surfaceMinHeight: CGFloat
    var keyMinHeight: CGFloat
    /// Gap between the surface, the key grid and the quick actions.
    var sectionSpacing: CGFloat
    var keySpacing: CGFloat

    static let regular = RemoteMetrics(surfaceShare: 0.5, surfaceMinHeight: 260,
                                       keyMinHeight: 64, sectionSpacing: 20, keySpacing: 16)
    static let compact = RemoteMetrics(surfaceShare: 0.42, surfaceMinHeight: 220,
                                       keyMinHeight: 52, sectionSpacing: 14, keySpacing: 12)
    static let tight = RemoteMetrics(surfaceShare: 0.34, surfaceMinHeight: 170,
                                     keyMinHeight: Theme.minTarget, sectionSpacing: 10, keySpacing: 10)
}

// MARK: - Swipe surface

/// Strictly 4-directional (no diagonals): the dominant axis must beat the other
/// by 20% or the gesture is ignored as ambiguous. A near-stationary touch is a
/// tap = Select. Repeat count scales with swipe velocity (1–4 presses).
private struct SwipeSurface: View {
    let onSwipe: (SwipeDirection, Int) -> Void
    let onSelect: () -> Void

    @State private var activeTrail: [CGPoint] = []
    @State private var fadingTrails: [Trail] = []
    @State private var selectPulse = false
    /// Which direction is currently lit (chevron + that wall of the border).
    /// Cleared by the newest swipe's own fade, so rapid swipes never leave a
    /// stale glow behind.
    @State private var litDirection: SwipeDirection?
    @State private var litToken = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tapThreshold: CGFloat = 20
    private let dominanceRatio: CGFloat = 1.2
    private let maxTrailPoints = 60

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

            // The wall the finger swiped toward, lit and fading back down.
            edgeGlow

            // Faint affordances — visible if you glance, ignorable if you don't.
            directionHints
            Circle()
                .strokeBorder(Color.white.opacity(selectPulse ? 0.5 : 0.12), lineWidth: 1.5)
                .frame(width: 72, height: 72)
                .scaleEffect(selectPulse ? 1.12 : 1)
            Text("OK")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(selectPulse ? 0.8 : 0.25))

            // Finger trail: draws live under the finger, then hangs for a
            // beat and fades. Completed trails fade independently so rapid
            // repeated swipes each read clearly.
            TrailCanvas(points: activeTrail)
            ForEach(fadingTrails) { trail in
                FadingTrailView(points: trail.points)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
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
            .onChanged { value in
                // Track the finger. Throttled to ≥3pt steps and capped in
                // length to keep Canvas redraws trivial (60/120fps safe).
                if let last = activeTrail.last {
                    let step = hypot(value.location.x - last.x, value.location.y - last.y)
                    guard step > 3 else { return }
                }
                activeTrail.append(value.location)
                if activeTrail.count > maxTrailPoints {
                    activeTrail.removeFirst(activeTrail.count - maxTrailPoints)
                }
            }
            .onEnded { value in
                retireTrail()

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

    /// Moves the live trail into the fading list; it lingers ~0.15s, fades
    /// over ~0.45s (opacity only — safe under Reduce Motion), then is removed.
    private func retireTrail() {
        guard activeTrail.count > 1 else {
            activeTrail = []
            return
        }
        let trail = Trail(points: activeTrail)
        fadingTrails.append(trail)
        activeTrail = []
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            fadingTrails.removeAll { $0.id == trail.id }
        }
    }

    private func fire(_ direction: SwipeDirection?, repeats: Int = 1) {
        if let direction {
            onSwipe(direction, repeats)
            light(direction)
        } else {
            onSelect()
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.7)) { selectPulse = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                withAnimation(.easeOut(duration: 0.3)) { selectPulse = false }
            }
        }
    }

    /// Snaps the highlight on, then fades it out. Each call takes ownership via
    /// a token so an interrupting swipe's fade can't cancel the newer glow.
    private func light(_ direction: SwipeDirection) {
        litToken += 1
        let token = litToken
        withAnimation(.easeOut(duration: 0.06)) { litDirection = direction }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard token == litToken else { return }
            withAnimation(.easeOut(duration: 0.35)) { litDirection = nil }
        }
    }

    /// Lights only the swiped wall: the accent is strongest at that edge and
    /// falls off to nothing by the centre, so the border reads as directional
    /// rather than as a full outline.
    @ViewBuilder private var edgeGlow: some View {
        if let litDirection {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0)],
                                   startPoint: litDirection.unitPoint,
                                   endPoint: .center),
                    lineWidth: 3
                )
                .shadow(color: Theme.accent.opacity(0.5), radius: 10)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private var directionHints: some View {
        VStack {
            hint(.up, "chevron.up")
            Spacer()
            HStack {
                hint(.left, "chevron.left")
                Spacer()
                hint(.right, "chevron.right")
            }
            Spacer()
            hint(.down, "chevron.down")
        }
        .font(.body.weight(.semibold))
        .padding(18)
        .allowsHitTesting(false)
    }

    /// Resting chevrons stay barely-there; the swiped one takes the accent and
    /// a matching glow. The nudge outward is motion, so it is dropped under
    /// Reduce Motion — the colour change alone still carries the feedback.
    private func hint(_ direction: SwipeDirection, _ symbol: String) -> some View {
        let isLit = litDirection == direction
        return Image(systemName: symbol)
            .foregroundStyle(isLit ? Theme.accent : Color.white.opacity(0.18))
            .shadow(color: isLit ? Theme.accent.opacity(0.9) : .clear, radius: 8)
            .scaleEffect(isLit && !reduceMotion ? 1.3 : 1)
    }
}

private struct Trail: Identifiable {
    let id = UUID()
    let points: [CGPoint]
}

/// Comet-style finger trail: brighter and wider toward the fingertip, dimmer
/// at the tail. Canvas + per-segment stroke keeps it a single cheap draw pass —
/// no image assets, crisp at any size and frame rate.
private struct TrailCanvas: View {
    let points: [CGPoint]

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }
            let count = points.count
            for index in 1..<count {
                var segment = Path()
                segment.move(to: points[index - 1])
                segment.addLine(to: points[index])
                // 0 at the tail → 1 at the fingertip.
                let t = Double(index) / Double(count)
                context.stroke(
                    segment,
                    with: .color(Theme.accent.opacity(0.12 + 0.7 * t)),
                    style: StrokeStyle(lineWidth: 6 + 9 * t,
                                       lineCap: .round, lineJoin: .round)
                )
            }
        }
        .blur(radius: 3)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

/// A completed trail: hangs for a brief moment, then fades out.
/// Opacity-only animation, so it stays appropriate under Reduce Motion.
private struct FadingTrailView: View {
    let points: [CGPoint]
    @State private var opacity: Double = 1

    var body: some View {
        TrailCanvas(points: points)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(0.15)) {
                    opacity = 0
                }
            }
    }
}

private enum SwipeDirection: Equatable {
    case up, down, left, right

    /// Where this direction's wall sits, for anchoring the edge-glow gradient.
    var unitPoint: UnitPoint {
        switch self {
        case .up: return .top
        case .down: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    var key: ECPKey {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
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

#if DEBUG
#Preview {
    NavigationStack {
        RemoteControlView()
    }
    .environmentObject(AppState())
    .environmentObject(EntitlementStore.preview())
}
#endif
