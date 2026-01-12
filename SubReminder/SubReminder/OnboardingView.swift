import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var page = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {

                OnboardingPage(
                    systemImage: "bell.badge",
                    title: "Never miss a charge",
                    subtitle: "Get reminders before your subscriptions renew."
                )
                .tag(0)

                OnboardingPage(
                    systemImage: "calendar",
                    title: "Track subscriptions",
                    subtitle: "See upcoming payments in one clean list."
                )
                .tag(1)

                OnboardingPage(
                    systemImage: "banknote",
                    title: "Save money",
                    subtitle: "Cancel unwanted subscriptions on time."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Text(page < 2 ? "Continue" : "Get started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if page < 2 {
                    Button("Skip") {
                        hasSeenOnboarding = true
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 40)
    }
}
