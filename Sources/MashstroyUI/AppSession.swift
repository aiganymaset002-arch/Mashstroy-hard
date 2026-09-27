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
}
#endif
