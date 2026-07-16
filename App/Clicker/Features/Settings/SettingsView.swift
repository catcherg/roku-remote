import SwiftUI
import RokuKit

/// Settings (Phase 3 task 8): haptics toggle, device management with default
/// device, Help, legal disclaimer (§1.5), privacy policy, version.
struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var renameTarget: RokuDevice?
    @State private var renameText = ""

    var body: some View {
        List {
            Section("Feedback") {
                Toggle("Haptics", isOn: $hapticsEnabled)
            }

            Section {
                ForEach(app.devices) { device in
                    deviceRow(device)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        app.forget(app.devices[offset])
                    }
                }
            } header: {
                Text("Devices")
            } footer: {
                Text("Tap a device to make it the default — Clicker connects to it automatically on launch. Swipe to forget.")
            }

            Section("Support") {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("Help & troubleshooting", systemImage: "questionmark.circle")
                }
                Link(destination: AppInfo.privacyPolicyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
            }

            Section {
                LabeledContent("Version", value: AppInfo.version)
            } footer: {
                Text(AppInfo.disclaimer)
                    .font(.caption2)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename device", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let target = renameTarget, !renameText.isEmpty {
                    app.rename(target, to: renameText)
                }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    @ViewBuilder
    private func deviceRow(_ device: RokuDevice) -> some View {
        let isDefault = app.store.lastConnected?.serialNumber == device.serialNumber
        Button {
            app.setDefault(device)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name)
                        .foregroundStyle(.primary)
                    Text("\(device.model) · \(device.ip)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isDefault {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .contextMenu {
            Button {
                renameTarget = device
                renameText = device.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
    }
}
