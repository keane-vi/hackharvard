import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            mainTabs
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
            CameraView()
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.dash")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}

#Preview {
    ContentView()
}
