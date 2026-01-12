import SwiftUI
import CoreData

@main
struct SubReminderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext,
                              persistenceController.container.viewContext)
        }
    }
}
