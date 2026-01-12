import SwiftUI
import CoreData
import UserNotifications

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Сортируем по ближайшей дате списания (вверх), затем по дате создания
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Subscription.billingDate, ascending: true),
            NSSortDescriptor(keyPath: \Subscription.createdAt, ascending: false)
        ],
        animation: .default
    )
    private var items: FetchedResults<Subscription>

    // Fake Pro (потом заменить на StoreKit)
    @StateObject private var proManager = ProManager()

    // UI
    @State private var showAdd = false
    @State private var showPaywall = false

    // Notifications status
    @State private var notificationsEnabled = false
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Pro banner
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: proManager.isPro ? "crown.fill" : "crown")
                            .foregroundStyle(proManager.isPro ? .yellow : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(proManager.isPro ? "Pro: Lifetime" : "Free plan")
                                .font(.subheadline).bold()

                            Text(proManager.isPro ? "Unlimited subscriptions" : "1 subscription included")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !proManager.isPro {
                            Button("Upgrade") { showPaywall = true }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Notifications status
                Section("Reminders") {
                    HStack(spacing: 10) {
                        Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash")
                            .foregroundStyle(notificationsEnabled ? .green : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(notificationsEnabled ? "Notifications: On" : "Notifications: Off")
                                .font(.subheadline).bold()

                            Text(notificationsEnabled
                                 ? "You will get reminders before charges."
                                 : "Enable notifications to receive reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !notificationsEnabled {
                            Button("Enable") {
                                Task { await requestNotifications() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Subscriptions list
                Section("Subscriptions") {
                    if items.isEmpty {
                        EmptyStateView {
                            addTapped()
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } else {
                        ForEach(items) { sub in
                            NavigationLink {
                                EditSubscriptionView(subscription: sub)
                            } label: {
                                SubscriptionRow(subscription: sub)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(sub)
                                                                    } label: {
                                                                        Label("Delete", systemImage: "trash")
                                                                    }
                                                                }
                                                            }
                                                            .onDelete(perform: deleteItems)
                                                        }
                                                    }
                                                }
                                                .navigationTitle("SubReminder")
                                                .toolbar {
                                                    ToolbarItem(placement: .topBarTrailing) {
                                                        Button {
                                                            addTapped()
                                                        } label: {
                                                            Image(systemName: "plus")
                                                        }
                                                    }
                                                }
                                                .sheet(isPresented: $showAdd) {
                                                    AddSubscriptionView()
                                                }
                                                .sheet(isPresented: $showPaywall) {
                                                    FakePaywallView(proManager: proManager)
                                                }
                                                .alert("Notifications are disabled", isPresented: $showPermissionAlert) {
                                                    Button("OK", role: .cancel) {}
                                                } message: {
                                                    Text("Please enable notifications in Settings to get reminders.")
                                                }
                                                .task {
                                                    await refreshNotificationStatus()
                                                }
                                            }
                                        }

                                        // MARK: - Actions

                                        private func addTapped() {
                                            if proManager.isPro || items.count < 1 {
                                                showAdd = true
                                            } else {
                                                showPaywall = true
                                            }
                                        }

                                        private func deleteItems(offsets: IndexSet) {
                                            withAnimation {
                                                offsets.map { items[$0] }.forEach { sub in
                                                    delete(sub)
                                                }
                                            }
                                        }

                                        private func delete(_ sub: Subscription) {
                                            if let id = sub.id {
                                                NotificationManager.shared.removeNotification(for: id)
                                            }
                                            viewContext.delete(sub)

                                            do {
                                                try viewContext.save()
                                            } catch {
                                                print("Delete save error:", error.localizedDescription)
                                            }
                                        }

                                        private func requestNotifications() async {
                                            do {
                                                let granted = try await NotificationManager.shared.requestAuthorization()
                                                await MainActor.run {
                                                    notificationsEnabled = granted
                                                    if !granted { showPermissionAlert = true }
                                                }
                                            } catch {
                                                await MainActor.run {
                                                    notificationsEnabled = false
                                                    showPermissionAlert = true
                                                }
                                            }
                                        }

                                        private func refreshNotificationStatus() async {
                                            let settings = await UNUserNotificationCenter.current().notificationSettings()
                                            await MainActor.run {
                                                notificationsEnabled = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
                                            }
                                        }
                                    }

                                    // MARK: - Row

                                    private struct SubscriptionRow: View {
                                        let subscription: Subscription

                                        var body: some View {
                                            HStack(alignment: .center, spacing: 12) {
                                                Image(systemName: iconName)
                                                    .font(.title3)
                                                    .foregroundStyle(iconColor)

                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(subscription.title ?? "Untitled")
                                                        .font(.headline)

                                                    Text(dateText)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)

                                                    if subscription.remindDaysBefore > 0, subscription.isActive {
                                                        Text("Remind \(subscription.remindDaysBefore) day(s) before")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    } else if !subscription.isActive {
                                                        Text("Paused")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    } else {
                                                        Text("No reminder")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }

                                                Spacer()

                                                VStack(alignment: .trailing, spacing: 3) {
                                                    Text(amountText)
                                                        .font(.headline)
                                                    Text(daysLeftText)
                                                                        .font(.caption)
                                                                        .foregroundStyle(.secondary)
                                                                }
                                                            }
                                                            .padding(.vertical, 6)
                                                        }

                                                        private var amountText: String {
                                                            let amount = subscription.amount
                                                            let cur = subscription.currency ?? "USD"
                                                            return String(format: "%.2f %@", amount, cur)
                                                        }

                                                        private var dateText: String {
                                                            guard let date = subscription.billingDate else { return "No date" }
                                                            let df = DateFormatter()
                                                            df.dateStyle = .medium
                                                            return "Next charge: \(df.string(from: date))"
                                                        }

                                                        private var daysLeftText: String {
                                                            guard let date = subscription.billingDate else { return "" }
                                                            let start = Calendar.current.startOfDay(for: Date())
                                                            let end = Calendar.current.startOfDay(for: date)
                                                            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0

                                                            if days < 0 { return "Overdue" }
                                                            if days == 0 { return "Today" }
                                                            if days == 1 { return "In 1 day" }
                                                            return "In \(days) days"
                                                        }

                                                        private var iconName: String {
                                                            if !subscription.isActive { return "pause.circle" }
                                                            if (subscription.remindDaysBefore == 0) { return "calendar" }
                                                            return "bell.badge"
                                                        }

                                                        private var iconColor: Color {
                                                            if !subscription.isActive { return .secondary }
                                                            if subscription.remindDaysBefore == 0 { return .blue }
                                                            return .green
                                                        }
                                                    }

                                                    // MARK: - Empty State

                                                    private struct EmptyStateView: View {
                                                        var onAdd: () -> Void

                                                        var body: some View {
                                                            VStack(spacing: 10) {
                                                                Image(systemName: "bell.badge")
                                                                    .font(.largeTitle)
                                                                    .foregroundStyle(.secondary)

                                                                Text("No subscriptions yet")
                                                                    .font(.headline)

                                                                Text("Add your first subscription and get notified before you’re charged.")
                                                                    .font(.subheadline)
                                                                    .foregroundStyle(.secondary)
                                                                    .multilineTextAlignment(.center)

                                                                Button {
                                                                    onAdd()
                                                                } label: {
                                                                    Text("Add subscription")
                                                                        .frame(maxWidth: .infinity)
                                                                }
                                                                .buttonStyle(.borderedProminent)
                                                                .padding(.top, 6)
                                                            }
                                                            .padding(.vertical, 16)
                                                        }
                                                    }
