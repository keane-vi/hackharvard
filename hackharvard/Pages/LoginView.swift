//
//  LoginView.swift
//  hackharvard
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.largeTitle.bold())

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isSignUp ? "Sign Up" : "Log In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up") {
                isSignUp.toggle()
                errorMessage = nil
            }
            .font(.footnote)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func submit() {
        errorMessage = nil

        if email == AuthManager.masterEmail && password == AuthManager.masterPassword {
            authManager.signInAsDemoUser()
            return
        }

        isLoading = true
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(email: email, password: password)
                } else {
                    try await authManager.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
