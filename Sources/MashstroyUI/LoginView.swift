//
//  LoginView.swift
//  MASHSTROY AI Control
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var role: UserRole = .engineer
    @State private var acceptedTerms = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MASHSTROY").font(.largeTitle.bold()).foregroundStyle(MashstroyTheme.primary)
                        Text("Industrial AI Control").font(.title3).foregroundStyle(MashstroyTheme.accent)
                    }
                    .padding(.vertical, 8)
                }
                Section("Вход") {
                    TextField("E-mail", text: $email)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                    SecureField("Пароль", text: $password)
                }
                Section {
                    Picker("Роль", selection: $role) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    Text(role.summary).font(.footnote).foregroundStyle(.secondary)
                } header: {
                    Text("Роль")
                } footer: {
                    Text("Демо-вход: данные никуда не отправляются. Роль выбирается вручную, пока нет сервера MASHSTROY Cloud.")
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
                        Task { await session.signIn(email: email, password: password, role: role) }
                    } label: {
                        HStack {
                            Spacer()
                            if session.isSigningIn { ProgressView() } else { Text("Войти").bold() }
                            Spacer()
                        }
                    }
                    .disabled(session.isSigningIn || !acceptedTerms)
                }
            }
            .navigationTitle("Вход")
        }
    }
}
#endif
