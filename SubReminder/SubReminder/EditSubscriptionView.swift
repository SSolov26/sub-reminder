import SwiftUI
import CoreData
import UIKit

struct EditSubscriptionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var subscription: Subscription

    // MARK: - Form state
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var currency: String = "USD"
    @State private var billingDate: Date = Date()
    @State private var remindDaysBefore: Int = 3
    @State private var isActive: Bool = true

    // MARK: - UI state
    @FocusState private var focusField: Field?
    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String = ""
    @State private var showDeleteConfirm: Bool = false

    private enum Field { case title, amount, currency }
    private let remindOptions = [0, 1, 3, 7]

    var body: some View {
        Form {
            Section("Subscription") {
                TextField("Name (e.g., Spotify)", text: $title)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focusField, equals: .title)

                TextField("Amount (e.g., 9.99)", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($focusField, equals: .amount)

                TextField("Currency (e.g., USD)", text: $currency)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusField, equals: .currency)

                Text("Tip: Use the amount you’re charged each cycle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Billing") {
                DatePicker("Next charge date", selection: $billingDate, displayedComponents: [.date])

                Text("The day when money will be charged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Remind me before", selection: $remindDaysBefore) {
                    ForEach(remindOptions, id: \.self) { d in
                        Text(d == 0 ? "No reminder" : "\(d) day(s)")
                            .tag(d)
                    }
                }

                Text("You’ll get a notification before the charge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Active", isOn: $isActive)
            }

            Section {
                Button {
                    hideKeyboard()
                    markAsPaid()
                } label: {
                    HStack {
                        Spacer()
                        Text("Mark as paid (+1 month)")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    hideKeyboard()
                    saveChanges()
                } label: {
                    HStack {
                        Spacer()
                        Text("Save changes").bold()
                        Spacer()
                    }
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete subscription")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Edit")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .onAppear { loadFromModel() }
        .alert("Can’t save", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .confirmationDialog("Delete subscription?",
                            isPresented: $showDeleteConfirm,
                                                        titleVisibility: .visible) {
                                        Button("Delete", role: .destructive) { deleteSubscription() }
                                        Button("Cancel", role: .cancel) {}
                                    }
                                }

                                // MARK: - Load
                                private func loadFromModel() {
                                    title = subscription.title ?? ""
                                    amountText = String(subscription.amount)
                                    currency = subscription.currency ?? "USD"
                                    billingDate = subscription.billingDate ?? Date()
                                    remindDaysBefore = Int(subscription.remindDaysBefore)
                                    isActive = subscription.isActive

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        focusField = .title
                                    }
                                }

                                // MARK: - Save
                                private func saveChanges() {
                                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmedTitle.isEmpty else {
                                        validationMessage = "Please enter a name."
                                        showValidationAlert = true
                                        focusField = .title
                                        return
                                    }

                                    let normalizedAmount = amountText
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .replacingOccurrences(of: ",", with: ".")

                                    guard let amount = Double(normalizedAmount), amount >= 0 else {
                                        validationMessage = "Please enter a valid amount (e.g., 9.99)."
                                        showValidationAlert = true
                                        focusField = .amount
                                        return
                                    }

                                    let trimmedCurrency = currency
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .uppercased()

                                    guard !trimmedCurrency.isEmpty else {
                                        validationMessage = "Please enter a currency (e.g., USD)."
                                        showValidationAlert = true
                                        focusField = .currency
                                        return
                                    }

                                    subscription.title = trimmedTitle
                                    subscription.amount = amount
                                    subscription.currency = trimmedCurrency
                                    subscription.billingDate = billingDate
                                    subscription.remindDaysBefore = Int16(remindDaysBefore)
                                    subscription.isActive = isActive

                                    do {
                                        try viewContext.save()
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                                        rescheduleNotificationIfNeeded(
                                            id: subscription.id,
                                            title: trimmedTitle,
                                            amount: amount,
                                            currency: trimmedCurrency,
                                            billingDate: billingDate,
                                            remindDaysBefore: remindDaysBefore,
                                            isActive: isActive
                                        )

                                        dismiss()
                                    } catch {
                                        validationMessage = "Save error: \(error.localizedDescription)"
                                        showValidationAlert = true
                                    }
                                }

                                // MARK: - Mark as paid (+1 month)
                                private func markAsPaid() {
                                    let current = billingDate

                                    guard let newDate = Calendar.current.date(byAdding: .month, value: 1, to: current) else {
                                        validationMessage = "Could not calculate next date."
                                        showValidationAlert = true
                                        return
                                    }

                                    // Обновляем UI + модель
                                    billingDate = newDate
                                    subscription.billingDate = newDate

                                    do {
                                        try viewContext.save()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()

                                        rescheduleNotificationIfNeeded(
                                            id: subscription.id,
                                            title: (subscription.title ?? title).trimmingCharacters(in: .whitespacesAndNewlines),
                                            amount: subscription.amount,
                                            currency: subscription.currency ?? currency,
                                            billingDate: newDate,
                                            remindDaysBefore: Int(subscription.remindDaysBefore),
                                            isActive: subscription.isActive
                                        )

                                        dismiss()
                                    } catch {
                                        validationMessage = "Save error: \(error.localizedDescription)"
                                        showValidationAlert = true
                                    }
                                }

                                // MARK: - Delete
                                private func deleteSubscription() {
                                    if let id = subscription.id {
                                        NotificationManager.shared.removeNotification(for: id)


                            }

                                    viewContext.delete(subscription)

                                    do {
                                        try viewContext.save()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        dismiss()
                                    } catch {
                                        validationMessage = "Delete error: \(error.localizedDescription)"
                                        showValidationAlert = true
                                    }
                                }

                                // MARK: - Notifications
                                private func rescheduleNotificationIfNeeded(
                                    id: UUID?,
                                    title: String,
                                    amount: Double,
                                    currency: String,
                                    billingDate: Date,
                                    remindDaysBefore: Int,
                                    isActive: Bool
                                ) {
                                    guard let id else { return }

                                    NotificationManager.shared.removeNotification(for: id)

                                    guard isActive, remindDaysBefore > 0 else { return }

                                    Task {
                                        try? await NotificationManager.shared.scheduleNotification(
                                            subscriptionID: id,
                                            title: title,
                                            amount: amount,
                                            currency: currency,
                                            billingDate: billingDate,
                                            remindDaysBefore: remindDaysBefore
                                        )
                                    }
                                }

                                // MARK: - Keyboard
                                private func hideKeyboard() {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                                    to: nil,
                                                                    from: nil,
                                                                    for: nil)
                                }
                            }
