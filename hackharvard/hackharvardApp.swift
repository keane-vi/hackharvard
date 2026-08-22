import SwiftUI

@main
struct hackharvardApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isSignedIn {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
        }
    }
}
