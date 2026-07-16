import SwiftUI

/// Last-resort connection (roadmap §1.2): the Roku shows its IP under
/// Settings → Network → About. Validated with a live device-info call.
struct ManualIPSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var ip = ""
    @State private var errorMessage: String?
    @State private var isConnecting = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.1.42", text: $ip)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                } header: {
                    Text("Roku IP address")
                } footer: {
                    Text("Find it on your Roku under Settings → Network → About.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await connect() }
                    } label: {
                        if isConnecting {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Checking…")
                            }
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(ip.isEmpty || isConnecting)
                }
            }
            .navigationTitle("Connect by IP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }

    private func connect() async {
        isConnecting = true
        errorMessage = await app.connectManually(ip: ip)
        isConnecting = false
        if errorMessage == nil {
            dismiss()
        }
    }
}
