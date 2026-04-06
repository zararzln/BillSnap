import SwiftUI
import SwiftData

@main
struct VippsARApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [BillSession.self, BillItem.self, Diner.self])
        }
    }
}
