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
            CameraView()
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
                .tag(1)
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
