//
//  LoginView.swift
//  MASHSTROY AI Control
//
//  Вход и регистрация в MASHSTROY Cloud. Роль выдаёт администратор
//  организации (таблица members), а не пользователь. Демо-режим на
//  симуляторе доступен всегда — в том числе для проверки App Review.
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(MashstroyCore)
import MashstroyCore
#endif

struct LoginView: View {
    private enum Step: String, CaseIterable, Identifiable {
        case signIn, signUp
        var id: String { rawValue }
        var title: String { self == .signIn ? "Вход" : "Регистрация" }
    }

    @EnvironmentObject private var session: AppSession
    @State private var step: Step = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var acceptedTerms = false
    @State private var showDemo = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        BrandLogo(maxHeight: 110)
                        Text("Industrial AI Control").font(.title3.bold()).foregroundStyle(MashstroyTheme.accent)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }

                if session.isCloudConfigured {
                    Section {
                        Picker("Действие", selection: $step) {
                            ForEach(Step.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if step == .signUp {
                            TextField("Имя и фамилия", text: $fullName)
                                #if os(iOS)
                                .textContentType(.name)
                                #endif
                        }
                        emailField
                        SecureField("Пароль (от 6 символов)", text: $password)
                            #if os(iOS)
                            .textContentType(step == .signIn ? .password : .newPassword)
                            #endif
                    } footer: {
                        if step == .signUp {
                            Text("После регистрации администратор вашей организации выдаст доступ к машинам и роль.")
                        }
                    }
                    consentSection
                    messages
                    Section {
                        Button {
                            Task {
                                if step == .signIn {
                                    await session.signIn(email: email, password: password)
                                } else {
                                    await session.signUp(email: email, password: password, fullName: fullName)
                                }
                            }
                        } label: {
                            primaryLabel(step == .signIn ? "Войти" : "Зарегистрироваться")
                        }
                        .disabled(session.isBusy || !acceptedTerms || email.isEmpty || password.isEmpty)
                    }
                    Section {
                        NavigationLink("Демо-режим на симуляторе") { DemoLoginView() }
                    } footer: {
                        Text("Без подключения к оборудованию: все данные и неисправности симулируются.")
                    }
                } else {
                    Section {
                        Text("Облако MASHSTROY не настроено в этой сборке. Доступен демо-режим на симуляторе.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    DemoLoginForm()
                }
            }
            .navigationTitle(step.title)
            .disabled(session.isRestoring)
            .overlay { if session.isRestoring { ProgressView("Восстанавливаем вход…") } }
        }
    }

    private var emailField: some View {
        TextField("E-mail", text: $email)
            .autocorrectionDisabled()
            #if os(iOS)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            #endif
    }

    private var consentSection: some View {
        Section {
            Toggle("Я принимаю условия использования и политику конфиденциальности", isOn: $acceptedTerms)
            NavigationLink(LegalDocument.terms.title) { LegalDocumentView(document: .terms) }
            NavigationLink(LegalDocument.privacy.title) { LegalDocumentView(document: .privacy) }
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let error = session.errorMessage {
            Section { Text(error).foregroundStyle(MashstroyTheme.critical) }
        }
        if let info = session.infoMessage {
            Section { Text(info).foregroundStyle(MashstroyTheme.ok) }
        }
    }

    private func primaryLabel(_ title: String) -> some View {
        HStack {
            Spacer()
            if session.isBusy { ProgressView() } else { Text(title).bold() }
            Spacer()
        }
    }
}

/// Отдельный экран демо-входа (когда облако настроено).
struct DemoLoginView: View {
    var body: some View {
        Form { DemoLoginForm() }
            .navigationTitle("Демо-режим")
    }
}

/// Демо-вход: любой e-mail и пароль от 6 символов, роль выбирается вручную.
struct DemoLoginForm: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var role: UserRole = .engineer
    @State private var acceptedTerms = false

    var body: some View {
        Section("Демо-вход") {
            TextField("E-mail", text: $email)
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
            SecureField("Пароль (от 6 символов)", text: $password)
        }
        Section {
            Picker("Роль", selection: $role) {
                ForEach(UserRole.allCases) { Text($0.title).tag($0) }
            }
            Text(role.summary).font(.footnote).foregroundStyle(.secondary)
        } header: {
            Text("Роль")
        } footer: {
            Text("Демо-режим: данные никуда не отправляются, машина и неисправности симулируются.")
        }
        Section {
            Toggle("Я принимаю условия использования и политику конфиденциальности", isOn: $acceptedTerms)
            NavigationLink(LegalDocument.terms.title) { LegalDocumentView(document: .terms) }
            NavigationLink(LegalDocument.privacy.title) { LegalDocumentView(document: .privacy) }
        }
        if let error = session.errorMessage {
            Section { Text(error).foregroundStyle(MashstroyTheme.critical) }
        }
        Section {
            Button {
                Task { await session.signInDemo(email: email, password: password, role: role) }
            } label: {
                HStack {
                    Spacer()
                    if session.isBusy { ProgressView() } else { Text("Войти в демо-режим").bold() }
                    Spacer()
                }
            }
            .disabled(session.isBusy || !acceptedTerms)
        }
    }
}
#endif
