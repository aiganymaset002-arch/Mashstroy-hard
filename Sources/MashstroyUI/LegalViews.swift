//
//  LegalViews.swift
//  MASHSTROY AI Control
//
//  Политика конфиденциальности, условия использования и правила
//  безопасности внутри приложения. Полные версии (RU/EN) — в docs/ и по
//  ссылкам из AppLinks.
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

enum LegalDocument: String, Identifiable, CaseIterable {
    case safety, privacy, terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safety: return "Правила безопасности"
        case .privacy: return "Политика конфиденциальности"
        case .terms: return "Условия использования"
        }
    }

    var fullVersion: URL? {
        switch self {
        case .safety: return nil
        case .privacy: return AppLinks.privacyPolicy
        case .terms: return AppLinks.terms
        }
    }

    var sections: [(String, String)] {
        switch self {
        case .safety:
            return [
                ("Приложение не заменяет аварийный стоп",
                 "MASHSTROY AI Control — дополнительный пульт мониторинга и управления. Основное средство остановки — физическая кнопка Emergency Stop на установке. Она должна быть исправна и доступна всегда."),
                ("Защиты работают на оборудовании",
                 "Контроллер ESP32 сам останавливает установку при превышении тока, температуры, вибрации, заклинивании, открытой защитной крышке и потере датчика, даже без связи с приложением."),
                ("Связь может пропасть",
                 "Команда из приложения может не дойти или прийти с задержкой. Не полагайтесь на приложение, если рядом с установкой находятся люди."),
                ("Рекомендации ИИ — подсказка",
                 "Диагнозы и прогнозы ИИ помогают найти причину, но не являются заключением специалиста. Решение о работе установки принимает ответственный сотрудник."),
                ("Только обученный персонал",
                 "Управлять установкой могут только сотрудники, прошедшие инструктаж по технике безопасности на этом оборудовании.")
            ]
        case .privacy:
            return [
                ("Кто обрабатывает данные",
                 "MASHSTROY (контакты — в разделе «Поддержка»). Мы обрабатываем данные только для работы приложения."),
                ("Какие данные",
                 "E-mail, имя, роль и идентификатор пользователя; записи техников в карточках аварий; журнал команд оборудованию. Данные датчиков оборудования не являются персональными."),
                ("Зачем",
                 "Вход и разграничение доступа по ролям, управление оборудованием, журнал аварий и обслуживания, безопасность и расследование инцидентов."),
                ("Чего мы не делаем",
                 "Не продаём данные, не показываем рекламу, не отслеживаем вас в других приложениях и на сайтах, не используем сторонние SDK аналитики."),
                ("Где хранятся",
                 "В облаке MASHSTROY Cloud (Supabase) с шифрованием при передаче. В демо-режиме данные остаются только на устройстве."),
                ("Ваши права",
                 "Вы можете запросить копию, исправление или удаление данных. Аккаунт удаляется в приложении: «Ещё → Удалить аккаунт»."),
                ("Дети",
                 "Приложение предназначено для сотрудников предприятий и не предназначено для детей.")
            ]
        case .terms:
            return [
                ("Назначение",
                 "Приложение предназначено для мониторинга и управления промышленным оборудованием MASHSTROY уполномоченными сотрудниками."),
                ("Безопасность",
                 "Пользователь соблюдает правила безопасности, приведённые в приложении. Приложение не является системой безопасности и не заменяет физический аварийный стоп."),
                ("Аккаунт и роли",
                 "Доступ выдаёт администратор организации. Не передавайте свой аккаунт другим лицам: все команды записываются в журнал от вашего имени."),
                ("Рекомендации ИИ",
                 "Диагнозы, вероятности и прогнозы ресурса носят справочный характер и могут быть неточными."),
                ("Ответственность",
                 "MASHSTROY не отвечает за ущерб от решений, принятых только на основании данных приложения, а также от сбоев связи."),
                ("Демо-режим",
                 "Без подключения к облаку приложение работает на симуляторе: данные и неисправности ненастоящие.")
            ]
        }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        List {
            ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.0).font(.headline)
                    Text(section.1).font(.body)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
            if let url = document.fullVersion {
                Section {
                    Link("Полная версия (RU / EN)", destination: url)
                }
            }
        }
        .navigationTitle(document.title)
    }
}

/// Экран при первом запуске: правила безопасности нужно принять до входа.
struct SafetyDisclaimerView: View {
    let onAccept: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Физическая кнопка Emergency Stop на установке — основное средство остановки", systemImage: "exclamationmark.octagon.fill")
                        .font(.headline)
                        .foregroundStyle(MashstroyTheme.critical)
                }
                ForEach(Array(LegalDocument.safety.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.0).font(.headline)
                        Text(section.1)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                Section {
                    Button(action: onAccept) {
                        Text("Понимаю и принимаю")
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }
            }
            .navigationTitle("Безопасность")
        }
    }
}
#endif
