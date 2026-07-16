import SwiftUI
import UIKit
import RokuKit

/// Device list (Phase 2 task 3): remembered devices instantly, live-updating
/// scan results, pull-to-rescan, manual IP, rename/forget, failure recovery.
struct DiscoveryView: View {
    @EnvironmentObject private var app: AppState
    @State private var showManualIP = false
    @State private var renameTarget: RokuDevice?
    @State private var renameText = ""

    var body: some View {
        List {
            if case .unreachable(let device) = app.connection {
                Section {
                    Label("\(device.name) stopped responding. It may be off, or your phone changed networks.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                }
            }

            Section {
                ForEach(app.devices) { device in
                    deviceRow(device)
                }
                if app.isScanning {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(app.devices.isEmpty ? "Scanning your network…" : "Still scanning…")
                            .foregroundStyle(.secondary)
                    }
                }
                if !app.isScanning && app.devices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Roku found")
                            .font(.headline)
                        Text("Make sure your Roku is on and on the same Wi-Fi as this phone, then pull down to rescan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Open iOS Settings for Clicker") {
                            openAppSettings()
                        }
                        .font(.footnote)
                        Text("If you previously denied Local Network access, re-enable it there.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Devices")
            }

            Section {
                Button {
                    showManualIP = true
                } label: {
                    Label("Connect by IP address", systemImage: "number")
                }
                NavigationLink {
                    HelpView()
                } label: {
                    Label("Help & troubleshooting", systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle("Clicker")
        .refreshable {
            app.startScan()
        }
        .task {
            if app.devices.isEmpty && !app.isScanning {
                app.startScan()
            }
        }
        .sheet(isPresented: $showManualIP) {
            ManualIPSheet()
        }
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
        Button {
            app.connect(to: device)
        } label: {
            HStack {
                Image(systemName: device.isTV ? "tv" : "appletvremote.gen4")
                VStack(alignment: .leading) {
                    Text(device.name)
                        .foregroundStyle(.primary)
                    Text("\(device.model) · \(device.ip)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contextMenu {
            Button {
                renameTarget = device
                renameText = device.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                app.forget(device)
            } label: {
                Label("Forget", systemImage: "trash")
            }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
