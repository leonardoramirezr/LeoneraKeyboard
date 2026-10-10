import SwiftUI

@main
struct LeoneraKeyboardApp: App {
    @StateObject private var store = ConfigurationStore()
    @StateObject private var dictation = DictationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(dictation)
                .onOpenURL { url in
                    dictation.handle(url)
                }
        }
    }
}
