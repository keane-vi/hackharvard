import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        mainTabs
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(1)
            CameraView()
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
                .tag(2)
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.dash")
                }
                .tag(3)
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(4)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
