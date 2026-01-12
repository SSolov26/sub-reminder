import SwiftUI

struct FakePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var proManager: ProManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                VStack(spacing: 8) {
                    Text("Unlock Lifetime Pro")
                        .font(.title2)
                        .bold()

                    Text("One-time purchase. No subscription.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Unlimited subscriptions", systemImage: "infinity")
                    Label("Smart reminders before charge", systemImage: "bell")
                    Label("No account. No tracking.", systemImage: "lock")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer()

                Button {
                    // FAKE покупка для теста
                    proManager.isPro = true
                    dismiss()
                } label: {
                    Text("Unlock Lifetime • $9.99")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Text("You’ll be able to restore purchases later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Pro")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
