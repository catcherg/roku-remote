import SwiftUI
import UIKit

/// Troubleshooting (Phase 2 task 8). The Limited-mode walkthrough uses the
/// EXACT Roku menu path (roadmap §1.4) — this screen is the difference between
/// a rescued user and a 1-star review.
struct HelpView: View {
    var body: some View {
        List {
            Section("Roku says no (most common fix)") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("If Clicker can see your Roku but buttons don't work — or nothing is found at all — your Roku is probably set to block app control. On the Roku itself (with its physical remote):")
                        .font(.footnote)
                    steps([
                        "Press Home",
                        "Settings",
                        "System",
                        "Advanced system settings",
                        "Control by mobile apps",
                        "Network access",
                        "Select “Default” (not “Limited”)",
                    ])
                    Text("Takes about 30 seconds. Some ISP-provided Rokus ship with this set to Limited.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Nothing found when scanning") {
                bullet("Phone and Roku must be on the same Wi-Fi network. Check both.")
                bullet("Guest networks and hotel Wi-Fi often block device-to-device traffic (“client isolation”). Use your main home network.")
                bullet("A VPN on this phone can silently block local discovery. Try turning it off and rescanning.")
                bullet("Wake the Roku: sticks can drop off the network in deep sleep. Press a button on the physical remote, then rescan.")
                bullet("Last resort: connect by IP address. On the Roku: Settings → Network → About shows its IP.")
            }

            Section("Local Network permission") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clicker needs iOS's Local Network permission to talk to your Roku. If you denied it, scanning finds nothing.")
                        .font(.footnote)
                    Button("Open iOS Settings for Clicker") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.footnote)
                }
                .padding(.vertical, 4)
            }

            Section("Device stopped responding") {
                bullet("The Roku may have been powered off, or your router gave it a new address. Pull down to rescan on the Devices screen — Clicker recognizes it by serial number and reconnects.")
            }

            Section {
                Text("Not affiliated with or endorsed by Roku, Inc. Roku is a trademark of Roku, Inc.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func steps(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(step)
                        .font(.footnote.weight(.medium))
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.footnote)
        .padding(.vertical, 2)
    }
}
