//
//  AppSession.swift
//  MASHSTROY AI Control
//
//  Вход в MASHSTROY Cloud (Supabase) или в демо-режим на симуляторе.
//  Если адрес и ключ облака не заданы, доступен только демо-режим.
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(MashstroyCore)
import MashstroyCore
#endif
#if canImport(MashstroyCloud)
import MashstroyCloud
#endif

public enum AppMode: Equatable, Sendable {
    case demo
    case cloud
}

@MainActor
public final class AppSession: ObservableObject {
    @Published public private(set) var user: AppUser?
    @Published public private(set) var mode: AppMode = .demo
    @Published public private(set) var isBusy = false
    @Published public private(set) var isRestoring = false
    @Published public var errorMessage: String?
    @Published public var infoMessage: String?

    public let cloud: MashstroyCloud?
    private let demoAuth: AuthService

    public init(cloud: MashstroyCloud? = MashstroyCloud(config: SupabaseConfig.load()),
                demoAuth: AuthService = DemoAuthService()) {
        self.cloud = cloud
        self.demoAuth = demoAuth
    }

    public var isCloudConfigured: Bool { cloud != nil }

    /// Восстанавливает вход в облако после перезапуска.
    public func restore() async {
        guard let cloud, user == nil else { return }
        isRestoring = true
        defer { isRestoring = false }
        if let restored = await cloud.restoreUser() {
            mode = .cloud
            user = restored
        }
    }

    public func signIn(email: String, password: String) async {
        guard let cloud else { return }
        await run {
            let signedIn = try await cloud.signIn(email: email, password: password)
            self.mode = .cloud
            self.user = signedIn
        }
    }

    public func signUp(email: String, password: String, fullName: String) async {
        guard let cloud else { return }
        guard password.count >= 6 else {
            errorMessage = AuthError.weakPassword.localizedDescription
            return
        }
        await run {
            switch try await cloud.signUp(email: email, password: password, fullName: fullName) {
            case .signedIn(let signedIn):
                self.mode = .cloud
                self.user = signedIn
            case .confirmEmail:
                self.infoMessage = "Мы отправили письмо на \(email). Подтвердите адрес и войдите. Доступ к машинам выдаёт администратор организации."
            }
        }
    }

    public func signInDemo(email: String, password: String, role: UserRole) async {
        await run {
            let signedIn = try await self.demoAuth.signIn(email: email, password: password, role: role)
            self.mode = .demo
            self.user = signedIn
        }
    }

    public func signOut() async {
        if mode == .cloud { await cloud?.signOut() }
        user = nil
    }

    /// Удаление аккаунта из приложения (App Store Review Guideline 5.1.1(v)).
    public func deleteAccount() async {
        guard let current = user else { return }
        await run {
            if self.mode == .cloud, let cloud = self.cloud {
                try await cloud.deleteAccount()
            } else {
                try await self.demoAuth.deleteAccount(current)
            }
            self.user = nil
        }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        infoMessage = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    static func describe(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("invalid login credentials") { return "Неверный e-mail или пароль" }
        if text.localizedCaseInsensitiveContains("email not confirmed") { return "Подтвердите e-mail по ссылке из письма" }
        if text.localizedCaseInsensitiveContains("already registered") { return "Этот e-mail уже зарегистрирован, войдите" }
        return text
    }
}
#endif
