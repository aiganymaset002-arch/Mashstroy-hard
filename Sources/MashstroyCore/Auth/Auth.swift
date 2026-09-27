//
//  Auth.swift
//  MASHSTROY AI Control
//
//  Роли пользователей и вход. Сейчас — демо-вход без сервера;
//  реальный AuthService подключится вместе с MASHSTROY Cloud.
//

import Foundation

public enum Permission: String, CaseIterable, Sendable {
    case controlMachine
    case emergencyStop
    case manageFaults
    case viewDiagnostics
    case viewHardware
    case viewHistory
    case simulateFaults
}

public enum UserRole: String, CaseIterable, Identifiable, Codable, Sendable {
    case owner, engineer, researcher, technician, client, intern, viewer

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .owner: return "Owner / CEO"
        case .engineer: return "Engineer"
        case .researcher: return "Researcher"
        case .technician: return "Technician"
        case .client: return "Client"
        case .intern: return "Student / Intern"
        case .viewer: return "Viewer"
        }
    }

    public var summary: String {
        switch self {
        case .owner: return "Полный доступ"
        case .engineer: return "Управление установкой"
        case .researcher: return "Эксперименты и данные"
        case .technician: return "Обслуживание и неисправности"
        case .client: return "Только своё оборудование"
        case .intern: return "Ограниченный Research Mode"
        case .viewer: return "Только просмотр"
        }
    }

    public var permissions: Set<Permission> {
        switch self {
        case .owner:
            return Set(Permission.allCases)
        case .engineer:
            return [.controlMachine, .emergencyStop, .manageFaults, .viewDiagnostics, .viewHardware, .viewHistory, .simulateFaults]
        case .researcher:
            // Research Mode с управлением стендом появится позже.
            return [.emergencyStop, .viewDiagnostics, .viewHardware, .viewHistory]
        case .technician:
            return [.emergencyStop, .manageFaults, .viewDiagnostics, .viewHardware, .viewHistory]
        case .client:
            return [.viewDiagnostics, .viewHistory]
        case .intern:
            return [.viewDiagnostics, .viewHistory]
        case .viewer:
            return [.viewDiagnostics, .viewHardware, .viewHistory]
        }
    }
}

public struct AppUser: Hashable, Sendable {
    public var name: String
    public var email: String
    public var role: UserRole

    public init(name: String, email: String, role: UserRole) {
        self.name = name
        self.email = email
        self.role = role
    }

    public func can(_ permission: Permission) -> Bool { role.permissions.contains(permission) }
}

public enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword

    public var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Введите корректный e-mail"
        case .weakPassword: return "Пароль должен быть не короче 6 символов"
        }
    }
}

public protocol AuthService: Sendable {
    func signIn(email: String, password: String, role: UserRole) async throws -> AppUser
}

/// Демо-вход: проверяет формат данных, роль выбирается вручную.
public struct DemoAuthService: AuthService {
    public init() {}

    public func signIn(email: String, password: String, role: UserRole) async throws -> AppUser {
        let email = email.trimmingCharacters(in: .whitespaces)
        let parts = email.split(separator: "@")
        guard parts.count == 2, parts[1].contains(".") else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.weakPassword }
        return AppUser(name: String(parts[0]), email: email, role: role)
    }
}
