import SwiftUI

@main
struct hackharvardApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .sheet(isPresented: .constant(!authManager.isSignedIn)) {
                    LoginView()
                        .environmentObject(authManager)
                        .interactiveDismissDisabled()
                }
        }
    }
}
