//
//  AppLinks.swift
//  MASHSTROY AI Control
//
//  Публичные адреса документов и поддержки. Эти же ссылки указываются
//  в App Store Connect (Privacy Policy URL, Support URL).
//  Перед публикацией замените на свой домен или GitHub Pages
//  (см. docs/APP_STORE_CHECKLIST.md).
//

import Foundation

public enum AppLinks {
    public static let privacyPolicy = URL(string: "https://aiganymaset002-arch.github.io/mashstroy-hard/privacy-policy")!
    public static let terms = URL(string: "https://aiganymaset002-arch.github.io/mashstroy-hard/terms")!
    public static let support = URL(string: "https://aiganymaset002-arch.github.io/mashstroy-hard/support")!
    public static let supportEmail = "support@mashstroy.kz"

    public static var supportMail: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    /// Версия для экрана «О приложении»: 1.0.0 (1).
    public static func versionString(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}
