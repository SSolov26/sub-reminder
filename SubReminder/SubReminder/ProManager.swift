import SwiftUI
import Combine

final class ProManager: ObservableObject {

    @Published var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "isPro")
        }
    }

    init() {
        self.isPro = UserDefaults.standard.bool(forKey: "isPro")
    }
}
