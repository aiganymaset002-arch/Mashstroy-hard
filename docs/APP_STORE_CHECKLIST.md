# Публикация MASHSTROY AI Control в App Store

Требования сверены с официальными страницами Apple в сентябре 2026 г.:
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/),
[Privacy manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files),
[Account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/),
[Age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/).

## Уже сделано в коде

| Требование | Где |
|---|---|
| Сборка iOS 16+, только iPhone, версия 1.0.0 (1), bundle id `kz.mashstroy.aicontrol` | `App/MashstroyAIControl.xcodeproj` |
| Манифест конфиденциальности (UserDefaults CA92.1, e-mail, имя, ID, контент, действия; без трекинга) — обязателен с мая 2024 | `App/MashstroyAIControl/PrivacyInfo.xcprivacy` |
| Флаг экспорта шифрования `ITSAppUsesNonExemptEncryption = NO` (только HTTPS) | `App/MashstroyAIControl/Info.plist` |
| Иконка 1024×1024 без прозрачности (временная, генерируется скриптом) | `Assets.xcassets/AppIcon`, `scripts/make_app_icon.py` |
| Экран запуска с логотипом | `Info.plist → UILaunchScreen`, `LaunchLogo`, `LaunchBackground` |
| Удаление аккаунта в приложении (Guideline 5.1.1(v)) | «Ещё → Удалить аккаунт»; в облаке `ms_delete_my_account()` |
| Согласие с условиями и политикой при входе, документы внутри приложения | `LoginView`, `LegalViews.swift` |
| Правила безопасности при первом запуске: приложение не заменяет физический E-Stop (Guideline 1.4.1) | `SafetyDisclaimerView` |
| Раздел «О приложении»: поддержка, e-mail, версия | «Ещё → О приложении» |
| Демо-режим для ревьюера (Guideline 2.1: реальное оборудование ревьюеру недоступно) | симулятор + `docs/APP_REVIEW_NOTES.md` |
| VoiceOver: подписи состояния, показателей, кнопок, камеры; системные шрифты с Dynamic Type | `Components.swift` и экраны |
| Нет рекламы, трекинга, сторонней аналитики, ATT не нужен | — |
| Ключи не в коде: адрес и anon key из `Config/Secrets.xcconfig` (в git не попадает) | `Config/`, `SupabaseConfig` |
| Политика конфиденциальности, условия, поддержка (RU + EN) | `docs/privacy-policy.md`, `docs/terms.md`, `docs/support.md` |

Sign in with Apple **не нужен**: вход по e-mail и паролю своей системы, без
Google/Facebook и других сторонних входов (Guideline 4.8). Если добавите
вход через Google — нужно будет добавить и Sign in with Apple.

## Что нужно сделать вам

### 1. Аккаунт и юридические данные
- [ ] Apple Developer Program — **$99 в год**, лучше на организацию
      (нужен D-U-N-S номер компании; бесплатно, оформление до 2 недель):
      https://developer.apple.com/programs/enroll/
- [ ] Заполните в `docs/privacy-policy.md` и `docs/terms.md` все места
      в **[скобках]**: юридическое название, БИН, адрес, регион серверов,
      срок хранения журналов.
- [ ] Заведите ящик **support@mashstroy.kz** (или замените адрес в
      `Sources/MashstroyCore/Common/AppLinks.swift` и в документах).
- [ ] Для продажи в ЕС: статус трейдера (DSA) в App Store Connect → Business.

### 2. Опубликовать документы по постоянным ссылкам
Ссылки в приложении ведут на GitHub Pages:
`https://aiganymaset002-arch.github.io/mashstroy-hard/privacy-policy` (и `/terms`, `/support`).
- [ ] GitHub → репозиторий → Settings → Pages → Source: *Deploy from a branch*,
      ветка `main`, папка `/docs`. Для приватного репозитория Pages доступен
      только на платном плане GitHub; иначе сделайте репозиторий публичным
      или разместите три страницы на сайте mashstroy.kz и поменяйте ссылки
      в `AppLinks.swift`.
- [ ] Откройте все три ссылки и убедитесь, что они открываются без входа.

### 3. Сборка
- [ ] **Xcode 26 или новее** — с 28 апреля 2026 App Store Connect принимает
      только сборки на iOS 26 SDK.
- [ ] В Xcode: Signing & Capabilities → Team = ваша команда. Если bundle id
      `kz.mashstroy.aicontrol` занят или не нравится — поменяйте
      (PRODUCT_BUNDLE_IDENTIFIER) и зарегистрируйте такой же в App Store Connect.
- [ ] Для облака: скопируйте `Config/Secrets.example.xcconfig` →
      `Config/Secrets.xcconfig`, впишите URL и anon key Supabase.
- [ ] Прогоните тесты (⌘U), проверьте на реальном iPhone.
- [ ] Product → Archive → Distribute App → App Store Connect → Upload.
- [ ] Желательно заменить временную иконку на дизайнерскую (1024×1024 PNG,
      без прозрачности и скруглений).

### 4. Карточка в App Store Connect (https://appstoreconnect.apple.com)
- [ ] My Apps → «+» → New App: платформа iOS, имя «MASHSTROY AI Control»
      (до 30 символов, должно быть уникальным), основной язык Русский,
      bundle id, SKU (например `mashstroy-ai-control`).
- [ ] Подзаголовок (до 30 символов), например «Умный конвейер и ИИ-диагностика».
- [ ] Описание, ключевые слова (до 100 символов), что нового.
- [ ] Категория: Business (дополнительно Productivity).
- [ ] Privacy Policy URL и Support URL — ссылки из шага 2.
- [ ] Скриншоты iPhone 6.9" (1320×2868 или 1290×2796), от 1 до 10 штук:
      вход, обзор, управление, ИИ, аварии, графики. Делайте в симуляторе
      iPhone 17 Pro Max (⌘S).
- [ ] Copyright: «2026 MASHSTROY».
- [ ] Цена: бесплатно (Pricing and Availability), страны.

### 5. App Privacy («этикетки конфиденциальности»)
App Store Connect → App Privacy → Get Started. Ответы, совпадающие с
манифестом:
- Do you collect data? **Yes**.
- **Contact Info → Email Address**: App Functionality; linked to user: Yes; tracking: No.
- **Contact Info → Name**: App Functionality; linked: Yes; tracking: No.
- **Identifiers → User ID**: App Functionality; linked: Yes; tracking: No.
- **User Content → Other User Content** (записи техников): App Functionality; linked: Yes; tracking: No.
- **Usage Data → Product Interaction** (журнал команд): App Functionality; linked: Yes; tracking: No.
- Всё остальное (Location, Health, Financial, Contacts, Photos, Browsing,
  Diagnostics, Advertising Data и т. д.) — **не собирается**.

### 6. Возрастной рейтинг
С сентября 2026 новый опросник обязателен при отправке. На все вопросы
о контенте — **None/No** (нет насилия, азартных игр, чатов, UGC для
публики, веб-доступа). Ожидаемый рейтинг **4+**; можно вручную поставить
выше (например 16+), так как приложение для сотрудников предприятий.

### 7. Экспорт шифрования
В приложении уже указано `ITSAppUsesNonExemptEncryption = NO`, вопрос при
загрузке не появится. Если спросят — «использует только стандартное
шифрование HTTPS iOS, освобождено от документов».

### 8. Информация для ревьюера (App Review Information)
- [ ] Создайте демо-аккаунт **review@mashstroy.kz / Review2026** в
      Supabase (роль engineer на лабораторной площадке), когда приложение
      будет подключено к облаку. Пока работает демо-вход — подойдёт любой.
- [ ] Вставьте текст из `docs/APP_REVIEW_NOTES.md` в поле Notes.
- [ ] Контакт: имя, телефон, e-mail человека, который ответит ревьюеру.

### 9. Отправка
- [ ] Выберите загруженную сборку → Add for Review → Submit.
- [ ] Обычно проверка занимает 1–3 дня. Если отклонят — ответ придёт в
      Resolution Center; пришлите его сюда, исправим.

## Риски отклонения и что с ними делать

| Риск | Как снижаем |
|---|---|
| 2.1 «приложение не работает / нужен доступ к оборудованию» | демо-режим на симуляторе и подробные Review Notes |
| 4.2 «минимальная функциональность» | 8 полноценных экранов, ИИ-диагностика, журнал аварий |
| 5.1.1 политика конфиденциальности, удаление аккаунта | ссылки в приложении и в карточке, удаление в «Ещё» |
| 1.4.1 физический вред | правила безопасности при первом запуске и в условиях |
| Демо-вход принимает любой e-mail | в Review Notes прямо сказано, что это демо-режим; после подключения Supabase вход станет настоящим |
| Бизнес-приложение только для своих сотрудников | если приложение не для широкой публики, рассмотрите Unlisted App или Apple Business Manager (Custom App) вместо публичного App Store |
