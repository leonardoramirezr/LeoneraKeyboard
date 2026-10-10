import SwiftUI

@main
struct LeoneraKeyboardApp: App {
    @StateObject private var store = ConfigurationStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
