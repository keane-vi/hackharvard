//
//  AuthManager.swift
//  hackharvard
//
//  Talks directly to Supabase's Auth (GoTrue) REST API over URLSession,
//  matching the same request style as VitalsAPI.swift.
//

import Foundation
import Combine

struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

private struct AuthResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let user: SupabaseUser
}

private struct AuthErrorBody: Decodable {
    let error_description: String?
    let msg: String?
    let error: String?
}

struct AuthError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct StoredSession: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String?
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var currentUser: SupabaseUser?

    private let baseURL: URL
    private let anonKey: String
    private let defaultsKey = "supabase.session"

    var isSignedIn: Bool { currentUser != nil }

    init() {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
            let urlString = plist["SUPABASE_URL"],
            let key = plist["SUPABASE_ANON_KEY"],
            let base = URL(string: urlString)
        else {
            fatalError("Missing or invalid Secrets.plist — copy Secrets.plist.example and fill in your Supabase project URL and anon key.")
        }
        baseURL = base
        anonKey = key
        restoreSession()
    }

    private func restoreSession() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let stored = try? JSONDecoder().decode(StoredSession.self, from: data)
        else { return }
        currentUser = SupabaseUser(id: stored.userId, email: stored.email)
    }

    func signUp(email: String, password: String) async throws {
        let response = try await authRequest(path: "auth/v1/signup", email: email, password: password)
        try persist(response)
    }

    func signIn(email: String, password: String) async throws {
        let response = try await authRequest(path: "auth/v1/token?grant_type=password", email: email, password: password)
        try persist(response)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        currentUser = nil
    }

    private func persist(_ response: AuthResponse) throws {
        let stored = StoredSession(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            userId: response.user.id,
            email: response.user.email
        )
        let data = try JSONEncoder().encode(stored)
        UserDefaults.standard.set(data, forKey: defaultsKey)
        currentUser = response.user
    }

    private func authRequest(path: String, email: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = try? JSONDecoder().decode(AuthErrorBody.self, from: data)
            let message = body?.error_description ?? body?.msg ?? body?.error ?? "Something went wrong. Please try again."
            throw AuthError(message: message)
        }

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
}
