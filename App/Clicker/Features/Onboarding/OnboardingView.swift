import SwiftUI

/// Polished onboarding (Phase 3 task 5): value prop → trial terms → permission
/// explainer → scan. The trial page discloses the terms before the trial
/// starts; the permission page still does its Phase 2 job — explain WHY before
/// iOS shows the Local Network dialog.
struct OnboardingView: View {
    private enum Step: Hashable {
        case value, trial, permission
    }

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var entitlements: EntitlementStore
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var step: Step = .value
    /// Decided once, when onboarding begins, so the trial page does not vanish
    /// from under the user the moment the trial starts. False on a reinstall
    /// where the App Store already has a trial or the unlock on record.
    @State private var includesTrialStep: Bool

    init(includesTrialStep: Bool) {
        _includesTrialStep = State(initialValue: includesTrialStep)
    }

    private var needsTrial: Bool { entitlements.access == .needsTrial }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                valuePropPage.tag(Step.value)
                if includesTrialStep {
                    TrialOfferContent()
                        .padding(.horizontal, 32)
                        .tag(Step.trial)
                }
                permissionPage.tag(Step.permission)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Group {
                if step == .trial && needsTrial {
                    TrialOfferButton()
                } else {
                    Button(action: advance) {
                        PurchaseButtonLabel(title: step == .permission ? "Find My Roku" : "Continue")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Theme.background.ignoresSafeArea())
        .onChange(of: entitlements.access) { access in
            // The trial just started (or a restore found the unlock): move on.
            if step == .trial, access.allowsRemote {
                withAnimation { step = .permission }
            }
        }
    }

    private func advance() {
        switch step {
        case .value:
            withAnimation { step = includesTrialStep ? .trial : .permission }
        case .trial:
            withAnimation { step = .permission }
        case .permission:
            if needsTrial && includesTrialStep {
                // Swiped past the trial page: the trial has to start first.
                withAnimation { step = .trial }
                return
            }
            Haptics.medium()
            hasOnboarded = true
            app.startScan() // triggers the iOS Local Network dialog
        }
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
