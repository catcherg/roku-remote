import SwiftUI

/// Minimal onboarding (Phase 2 task 2): explain WHY before iOS shows the
/// Local Network permission dialog, which fires on the first network op.
struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "av.remote")
                .font(.system(size: 64))

            Text("Clicker")
                .font(.largeTitle.bold())

            Text("Control any Roku on your Wi-Fi.\nNo account. No setup. No nonsense.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Label {
                    Text("iOS will ask for **Local Network** access. Clicker needs it to find and talk to your Roku — nothing leaves your Wi-Fi, ever.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "wifi")
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    hasOnboarded = true
                    app.startScan() // triggers the permission dialog
                } label: {
                    Text("Find My Roku")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}
