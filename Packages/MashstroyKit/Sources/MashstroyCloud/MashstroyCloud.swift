//
//  MashstroyCloud.swift
//  MASHSTROY AI Control
//
//  Клиент MASHSTROY Cloud (Supabase): вход, регистрация, удаление аккаунта,
//  список машин. Доступ к данным ограничивают правила RLS в базе, поэтому
//  приложение использует только публичный ключ sb_publishable_….
//

import Foundation
#if canImport(MashstroyCore)
import MashstroyCore
#endif
import Supabase

public enum CloudError: LocalizedError {
    case noSession
    case noMachineState(String)

    public var errorDescription: String? {
        switch self {
        case .noSession: return "Сессия истекла, войдите снова"
        case .noMachineState(let serial): return "От машины \(serial) ещё не приходили данные. Проверьте, что ESP32 и шлюз подключены к облаку."
        }
    }
}

public enum SignUpOutcome: Sendable {
    case signedIn(AppUser)
    case confirmEmail
}

public final class MashstroyCloud: @unchecked Sendable {
    public let client: SupabaseClient

    public init(config: SupabaseConfig) {
        client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    /// nil, если адрес или ключ не заданы — тогда приложение работает в демо-режиме.
    public convenience init?(config: SupabaseConfig?) {
        guard let config else { return nil }
        self.init(config: config)
    }

    // MARK: Аккаунт

    public func signIn(email: String, password: String) async throws -> AppUser {
        let session = try await client.auth.signIn(email: normalized(email), password: password)
        return try await appUser(for: session.user)
    }

    public func signUp(email: String, password: String, fullName: String) async throws -> SignUpOutcome {
        let response = try await client.auth.signUp(
            email: normalized(email), password: password,
            data: ["full_name": .string(fullName.trimmingCharacters(in: .whitespacesAndNewlines))])
        switch response {
        case .session(let session):
            return .signedIn(try await appUser(for: session.user))
        case .user:
            return .confirmEmail
        }
    }

    /// Восстанавливает сохранённую сессию (Keychain) при запуске.
    public func restoreUser() async -> AppUser? {
        guard let session = try? await client.auth.session else { return nil }
        return try? await appUser(for: session.user)
    }

    public func signOut() async {
        try? await client.auth.signOut()
    }

    /// Удаляет аккаунт на сервере (public.ms_delete_my_account) и выходит.
    public func deleteAccount() async throws {
        try await client.rpc("ms_delete_my_account").execute()
        try? await client.auth.signOut(scope: .local)
    }

    private func appUser(for user: User) async throws -> AppUser {
        let members: [MemberRow] = try await client.from("members")
            .select("org_id,role,full_name")
            .eq("user_id", value: user.id.uuidString)
            .eq("blocked", value: false)
            .execute()
            .value
        let email = user.email ?? ""
        let metaName: String? = {
            if case .string(let name)? = user.userMetadata["full_name"], !name.isEmpty { return name }
            return nil
        }()
        let name = members.first { !$0.fullName.isEmpty }?.fullName
            ?? metaName
            ?? String(email.split(separator: "@").first ?? "")
        return AppUser(name: name, email: email, role: MemberRow.strongestRole(members))
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: Машины

    public func machines() async throws -> [MachineRow] {
        try await client.from("machines")
            .select("id,serial,type,name,sites(name)")
            .order("serial")
            .execute()
            .value
    }

    public func link(for machine: MachineRow) -> CloudConveyorLink {
        CloudConveyorLink(client: client, machine: machine)
    }
}
