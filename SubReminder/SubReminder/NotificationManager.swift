import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func removeNotification(for subscriptionID: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            notificationId(for: subscriptionID)
        ])
    }

    func scheduleNotification(
        subscriptionID: UUID,
        title: String,
        amount: Double,
        currency: String,
        billingDate: Date,
        remindDaysBefore: Int
    ) async throws {
        // Сначала чистим старое (на всякий случай)
        removeNotification(for: subscriptionID)

        let center = UNUserNotificationCenter.current()

        // Дата уведомления = billingDate - remindDaysBefore
        guard let fireDate = Calendar.current.date(byAdding: .day, value: -remindDaysBefore, to: billingDate) else {
            return
        }

        // Если дата в прошлом — не планируем
        if fireDate <= Date() { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming charge"
        let amountStr = String(format: "%.2f", amount)
        content.body = "\(title) — \(amountStr) \(currency) soon"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        // Уведомление в 10:00 по умолчанию, если время не задано
        var finalComponents = components
        if finalComponents.hour == nil { finalComponents.hour = 10 }
        if finalComponents.minute == nil { finalComponents.minute = 0 }

        let trigger = UNCalendarNotificationTrigger(dateMatching: finalComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId(for: subscriptionID),
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    private func notificationId(for id: UUID) -> String {
        "subreminder.\(id.uuidString)"
    }
}
