//
//  AppSession.swift
//  MASHSTROY AI Control
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

@MainActor
public final class AppSession: ObservableObject {
    @Published public private(set) var user: AppUser?
    @Published public private(set) var isSigningIn = false
    @Published public var errorMessage: String?

    private let auth: AuthService

    public init(auth: AuthService = DemoAuthService()) {
        self.auth = auth
    }

    public func signIn(email: String, password: String, role: UserRole) async {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            user = try await auth.signIn(email: email, password: password, role: role)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func signOut() {
        user = nil
    }

    /// Удаление аккаунта из приложения (App Store Review Guideline 5.1.1(v)).
    public func deleteAccount() async {
        guard let user else { return }
        errorMessage = nil
        do {
            try await auth.deleteAccount(user)
            self.user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
