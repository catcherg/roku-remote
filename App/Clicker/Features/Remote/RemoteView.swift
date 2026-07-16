import SwiftUI
import RokuKit

/// Functional remote layout (Phase 2 task 5) — complete, not pretty.
/// Volume/power cluster renders ONLY when the device is a TV (CLAUDE.md rule).
struct RemoteView: View {
    @EnvironmentObject private var app: AppState
    @State private var showKeyboard = false
    @State private var showChannels = false
    @State private var showLimitedHelp = false

    private var isTV: Bool { app.device?.isTV ?? false }

    var body: some View {
        VStack(spacing: 20) {
            topRow
            dPad
            secondaryRow
            transportRow
            if isTV {
                volumeRow
            }
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(app.device?.name ?? "Remote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    app.disconnect()
                } label: {
                    Label("Devices", systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showKeyboard = true } label: {
                    Image(systemName: "keyboard")
                }
                Button { showChannels = true } label: {
                    Image(systemName: "square.grid.3x3")
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
            }
        }
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

    // MARK: - Clusters

    private var topRow: some View {
        HStack {
            keyButton(.back, "chevron.backward", label: "Back")
            Spacer()
            if isTV {
                keyButton(.power, "power", label: "Power")
                    .tint(.red)
                Spacer()
            }
            keyButton(.home, "house", label: "Home")
        }
        .padding(.horizontal, 24)
    }

    private var dPad: some View {
        VStack(spacing: 8) {
            keyButton(.up, "chevron.up", label: "Up", size: 64)
            HStack(spacing: 8) {
                keyButton(.left, "chevron.backward", label: "Left", size: 64)
                Button {
                    app.send(.select)
                } label: {
                    Text("OK")
                        .font(.title2.bold())
                        .frame(width: 84, height: 84)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Select")
                keyButton(.right, "chevron.forward", label: "Right", size: 64)
            }
            keyButton(.down, "chevron.down", label: "Down", size: 64)
        }
    }

    private var secondaryRow: some View {
        HStack(spacing: 24) {
            keyButton(.instantReplay, "arrow.uturn.backward", label: "Instant replay")
            keyButton(.info, "asterisk", label: "Options")
            keyButton(.search, "magnifyingglass", label: "Search")
        }
    }

    private var transportRow: some View {
        HStack(spacing: 24) {
            keyButton(.rev, "backward.fill", label: "Rewind")
            keyButton(.play, "playpause.fill", label: "Play or pause")
            keyButton(.fwd, "forward.fill", label: "Fast forward")
        }
    }

    private var volumeRow: some View {
        HStack(spacing: 24) {
            keyButton(.volumeMute, "speaker.slash.fill", label: "Mute")
            keyButton(.volumeDown, "speaker.minus.fill", label: "Volume down")
            keyButton(.volumeUp, "speaker.plus.fill", label: "Volume up")
        }
    }

    private func keyButton(_ key: ECPKey, _ symbol: String,
                           label: String, size: CGFloat = 52) -> some View {
        Button {
            app.send(key)
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: size, height: size)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}
