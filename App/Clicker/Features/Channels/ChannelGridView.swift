import SwiftUI
import UIKit
import RokuKit

/// Channel launcher grid (Phase 2 task 7): /query/apps + lazy icons + tap to launch.
struct ChannelGridView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var apps: [RokuApp] = []
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading channels…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if apps.isEmpty {
                    VStack(spacing: 8) {
                        Text("Couldn't load channels")
                            .font(.headline)
                        Text("If this keeps happening, your Roku may be in Limited mode — see Help.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(apps) { channel in
                                channelCell(channel)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                apps = await app.fetchApps()
                isLoading = false
            }
        }
    }

    private func channelCell(_ channel: RokuApp) -> some View {
        Button {
            app.launchChannel(channel)
            dismiss()
        } label: {
            VStack(spacing: 6) {
                ChannelIconView(channel: channel)
                    .frame(width: 96, height: 72)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                Text(channel.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityLabel("Launch \(channel.name)")
    }
}

/// Loads one icon through the cache; shows a placeholder while loading.
struct ChannelIconView: View {
    @EnvironmentObject private var app: AppState
    let channel: RokuApp
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "app.dashed")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .task {
            guard imageData == nil, let device = app.device else { return }
            imageData = await app.icons.icon(appID: channel.id, ip: device.ip,
                                             client: app.client)
        }
    }
}
