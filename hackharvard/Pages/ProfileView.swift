//
//  ProfileView.swift
//  hackharvard
//
//  Created by Nanond Nimitkul on 22/8/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Profile")
            if let email = authManager.currentUser?.email {
                Text(email)
                    .foregroundStyle(.secondary)
            }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        }
    }
}

