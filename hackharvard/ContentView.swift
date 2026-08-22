//
//  ContentView.swift
//  hackharvard
//
//  Created by Nanond Nimitkul on 22/8/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }

            Text("Search")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            CameraView()
                .tabItem { Label("Camera", systemImage: "camera") }

            Text("Notifications")
                .tabItem { Label("Notifications", systemImage: "bell") }

            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person") }
        }
    }
}

#Preview {
    ContentView()
}
