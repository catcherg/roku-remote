import SwiftUI

/// Connected-device pill with a live status dot (Phase 3 task 4).
/// Green = connected, pulsing yellow = reconnecting.
struct StatusPill: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(app.isReconnecting ? Theme.statusReconnecting : Theme.statusConnected)
                .frame(width: 8, height: 8)
                .opacity(app.isReconnecting && pulsing && !reduceMotion ? 0.3 : 1)
                .animation(
                    app.isReconnecting && !reduceMotion
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )
            Text(app.device?.name ?? "Not connected")
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.keyFill))
        .onAppear { pulsing = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            app.isReconnecting
                ? "Reconnecting to \(app.device?.name ?? "device")"
                : "Connected to \(app.device?.name ?? "no device")"
        )
    }
}
