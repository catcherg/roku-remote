import SwiftUI
import RokuKit

/// Premium remote (Phase 3 task 2). Grouped clusters, primary controls in the
/// thumb zone (bottom 60%), press animations + haptics on everything.
/// Volume/power render ONLY when the device is a TV (CLAUDE.md rule).
struct RemoteView: View {
    @EnvironmentObject private var app: AppState
    @State private var showKeyboard = false
    @State private var showChannels = false
    @State private var showLimitedHelp = false

    private var isTV: Bool { app.device?.isTV ?? false }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                topCluster
                    .padding(.top, 8)

                Spacer(minLength: 12)

                // Primary controls live in the bottom ~60% for thumb reach.
                DPadView(size: min(proxy.size.width - 96, 280))

                Spacer(minLength: 16)

                mediaCluster

                if isTV {
                    volumeCluster
                        .padding(.top, 14)
                }

                quickActions
                    .padding(.top, 18)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Haptics.light()
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
                        Haptics.rigid()
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

    // MARK: - Clusters

    private var topCluster: some View {
        HStack {
            key(.back, "arrow.backward", label: "Back", haptic: Haptics.light)
            Spacer()
            key(.instantReplay, "arrow.uturn.backward", label: "Instant replay", haptic: Haptics.light)
            Spacer()
            key(.info, "asterisk", label: "Options", haptic: Haptics.light)
            Spacer()
            key(.home, "house.fill", label: "Home", haptic: Haptics.medium)
        }
        .padding(.horizontal, 8)
    }

    private var mediaCluster: some View {
        HStack(spacing: 28) {
            key(.rev, "backward.fill", label: "Rewind", haptic: Haptics.light)
            key(.play, "playpause.fill", label: "Play or pause", haptic: Haptics.medium, diameter: 64)
            key(.fwd, "forward.fill", label: "Fast forward", haptic: Haptics.light)
        }
    }

    private var volumeCluster: some View {
        HStack(spacing: 28) {
            key(.volumeMute, "speaker.slash.fill", label: "Mute", haptic: Haptics.medium)
            HoldKeyButton(key: .volumeDown, symbol: "speaker.minus.fill", label: "Volume down, hold to ramp")
            HoldKeyButton(key: .volumeUp, symbol: "speaker.plus.fill", label: "Volume up, hold to ramp")
        }
    }

    private var quickActions: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.light()
                showKeyboard = true
            } label: {
                Label("Keyboard", systemImage: "keyboard")
            }
            .buttonStyle(CapsuleActionStyle())
            .accessibilityHint("Type on the Roku with your phone keyboard")

            Button {
                Haptics.light()
                showChannels = true
            } label: {
                Label("Channels", systemImage: "square.grid.3x3")
            }
            .buttonStyle(CapsuleActionStyle())
            .accessibilityHint("Browse and launch installed channels")

            Button {
                Haptics.light()
                app.send(.search)
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(CapsuleActionStyle())
        }
    }

    private func key(_ ecpKey: ECPKey, _ symbol: String, label: String,
                     haptic: @escaping () -> Void, diameter: CGFloat = 52) -> some View {
        Button {
            haptic()
            app.send(ecpKey)
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(RemoteKeyStyle(diameter: diameter))
        .accessibilityLabel(label)
    }
}
