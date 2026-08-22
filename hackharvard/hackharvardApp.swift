import SwiftUI
import SwiftData

@main
struct hackharvardApp: App {
    var body: some Scene {
        WindowGroup {
            SeededContentView()
        }
        .modelContainer(for: ScanRecord.self)
    }
}

private struct SeededContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView()
            .task {
                LocalFixtureLoader.seedIfAvailable(in: modelContext)
            }
    }
}
