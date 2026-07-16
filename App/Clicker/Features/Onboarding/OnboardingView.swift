import SwiftUI

/// Polished onboarding (Phase 3 task 5): value prop → permission explainer →
/// scan. The permission page still does its Phase 2 job — explain WHY before
/// iOS shows the Local Network dialog.
struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                valuePropPage.tag(0)
                permissionPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page == 0 {
                    withAnimation { page = 1 }
                } else {
                    Haptics.medium()
                    hasOnboarded = true
                    app.startScan() // triggers the iOS Local Network dialog
                }
            } label: {
                Text(page == 0 ? "Continue" : "Find My Roku")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var valuePropPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "av.remote")
                .font(.system(size: 72))
                .foregroundStyle(Theme.accent)
            Text("Clicker")
                .font(.system(.largeTitle, design: .rounded).bold())
            Text("The premium remote for your Roku.\nNo account. No ads. No subscriptions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var permissionPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
            Text("Your Wi-Fi, and only your Wi-Fi")
                .font(.system(.title2, design: .rounded).bold())
                .multilineTextAlignment(.center)
            Text("iOS will ask for **Local Network** access next. Clicker needs it to find and control your Roku. Nothing ever leaves your network — there's no server, no analytics, no tracking.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
