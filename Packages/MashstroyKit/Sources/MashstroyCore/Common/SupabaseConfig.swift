//
//  SupabaseConfig.swift
//  MASHSTROY AI Control
//
//  Адрес и публичный ключ проекта MASHSTROY Cloud. Значения не хранятся
//  в репозитории: их задают переменными окружения схемы Xcode или
//  ключами Info.plist. Пока значений нет, приложение работает на симуляторе.
//

import Foundation

public struct SupabaseConfig: Equatable, Sendable {
    public static let urlKey = "MASHSTROY_SUPABASE_URL"
    /// Публичный ключ sb_publishable_… (Project Settings → API Keys).
    public static let publishableKeyKey = "MASHSTROY_SUPABASE_PUBLISHABLE_KEY"
    /// Старое имя для legacy anon-ключа, поддерживается для совместимости.
    public static let anonKeyKey = "MASHSTROY_SUPABASE_ANON_KEY"

    public let url: URL
    /// Публичный ключ (publishable или legacy anon). Секретный ключ сюда не попадает.
    public let anonKey: String

    public init?(url: String?, anonKey: String?) {
        guard let rawURL = Self.clean(url), let key = Self.clean(anonKey), !key.hasPrefix("sb_secret_"),
              let parsed = URL(string: rawURL), parsed.scheme == "https", parsed.host != nil else {
            return nil
        }
        self.url = parsed
        self.anonKey = key
    }

    /// Берёт значения из окружения, затем из Info.plist. nil — облако не настроено.
    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment,
                            infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> SupabaseConfig? {
        func value(_ key: String) -> String? {
            clean(environment[key]) ?? clean(infoDictionary?[key] as? String)
        }
        return SupabaseConfig(url: value(urlKey), anonKey: value(publishableKeyKey) ?? value(anonKeyKey))
    }

    /// Пустые значения, заглушки и неподставленные переменные сборки считаются отсутствующими.
    static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              !trimmed.contains("YOUR_"), !trimmed.contains("$(") else {
            return nil
        }
        return trimmed
    }
}
