import SwiftUI
import CoreData
import UIKit

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Form state
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var currency: String = "USD"

    // Дефолт: сегодня + 7 дней (лучший UX)
    @State private var billingDate: Date =
        Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    // Дефолт: 3 дня
    @State private var remindDaysBefore: Int = 3

    @State private var isActive: Bool = true

    // MARK: - UI state
    @FocusState private var focusField: Field?
    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String = ""

    private enum Field { case title, amount, currency }

    private let remindOptions = [0, 1, 3, 7]

    var body: some View {
        NavigationStack {
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
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save subscription").bold()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                // Удобно: кнопка Done для закрытия клавиатуры (iOS покажет её над формой)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .onAppear {
                // Автофокус на названии — быстрее ввод
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focusField = .title
                }
            }
            .alert("Can’t save", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Save
    private func save() {


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

        let sub = Subscription(context: viewContext)
        sub.id = UUID()
        sub.title = trimmedTitle
        sub.amount = amount
        sub.currency = trimmedCurrency
        sub.billingDate = billingDate
        sub.remindDaysBefore = Int16(remindDaysBefore)
        sub.isActive = isActive
        sub.createdAt = Date()

        do {
            try viewContext.save()

            // Haptic: ощущение “сохранено”
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Планируем уведомление, если нужно
            if isActive, remindDaysBefore > 0, let id = sub.id {
                Task {
                    try? await NotificationManager.shared.scheduleNotification(
                        subscriptionID: id,
                        title: trimmedTitle,
                        amount: amount,
                        currency: trimmedCurrency,
                        billingDate: billingDate,
                        remindDaysBefore: remindDaysBefore
                    )
                }
            }

            dismiss()
        } catch {
            validationMessage = "Save error: \(error.localizedDescription)"
            showValidationAlert = true
        }
    }

    // MARK: - Keyboard helper
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
    }
}
