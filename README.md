# MASHSTROY AI Control

Промышленное приложение MASHSTROY для управления оборудованием с ИИ.
Главный модуль — **Smart Conveyor**. Далее подключаются очистка воды,
переработка шлама, лабораторные установки и будущие машины.

Сейчас это MVP на симуляторе: все данные идут из `ConveyorSimulator`,
который ведёт себя как ESP32 с датчиками. Реальный контроллер
подключается заменой одного класса (см. «Подключение ESP32»).

## Экраны MVP

| Экран | Что есть |
|---|---|
| **Вход** | Демо-вход с выбором роли: Owner, Engineer, Researcher, Technician, Client, Intern, Viewer. Права ограничивают управление и аварии. |
| **Обзор** | Состояние RUNNING / PAUSED / STOPPED / WARNING / FAULT / EMERGENCY, ESP32 онлайн, скорость, обороты, ток, напряжение, мощность, нагрузка, давление воздуха, температуры двигателя и подшипников, вибрация, кг/ч, время работы, циклы, режим, предупреждения, прогноз ТО, камера. |
| **Управление** | Start, Pause, Stop, Emergency Stop, Reset Fault, скорость, ручной/авто режим, направление, вентиляторы, воздушная подушка, привод, бункер, пресс, режимы Eco Brick / Sludge / Transport / Research. Каждая команда проходит проверку безопасности. |
| **Датчики и ESP32** | ESP32 Main Controller (ID, IP, прошивка, Wi-Fi, RSSI, uptime) и 12 модулей: Motor Controller, BTS7960, INA219/226, HX711, MPU6050, Hall/Encoder, давление, температуры, концевики, камера, вентиляторы, пресс. |
| **Камера** | Условная картинка ленты и события компьютерного зрения: смещение ленты, материал, бункер, заклинивание, человек в зоне, дым, качество кирпича. |
| **ИИ** | Для каждого диагноза: что произошло → причина → вероятность → что проверить → срочность. Здоровье узлов (двигатель, подшипники, лента, воздушная камера, пресс) и RUL ± погрешность. |
| **Аварии** | Fault Center: карточки `FAULT-ГГГГ-NNNNN`, путь Новая → Accepted → Repairing → Resolved, запись техника о реальной причине. |
| **Графики** | Любой датчик за Live / 1 ч / 24 ч / 7 дн / 30 дн, min / max / среднее, граница нормы. |

В «Ещё → Симуляция неисправностей» можно включить износ подшипника,
перегрузку, утечку воздуха, сход ленты, заклинивание, отказ охлаждения,
человека в опасной зоне и потерю связи с ESP32.

## Как запустить

Одной командой (Xcode 16.3 или новее, лучше Xcode 26):

```
./scripts/run-simulator.sh
```

Скрипт соберёт приложение, включит симулятор iPhone и откроет в нём MASHSTROY AI.

Через Xcode:
1. Закройте другие окна Xcode с этой папкой (особенно открытый `Package.swift`).
2. Откройте `App/MashstroyAIControl.xcodeproj`.
3. Выберите схему **MashstroyAIControl** и симулятор iPhone, нажмите ▶︎ (⌘R).
4. Для запуска на своём iPhone: Signing & Capabilities → выберите свою Team.

Приложение компилирует папку `Sources/` напрямую, локальный пакет ему не нужен.
Без `Config/Secrets.xcconfig` оно работает в демо-режиме на симуляторе.

Тесты: `swift test` в корне репозитория (или ⌘U в Xcode).

## Структура

```
mashstroy-hard/
├── App/                          iOS-приложение (Xcode-проект)
├── Package.swift
├── Sources/
│   ├── MashstroyCore/            логика без UI (покрыта тестами)
│   │   ├── Auth/                 роли, права, вход
│   │   ├── Common/               RiskLevel, генератор, SupabaseConfig
│   │   ├── Modules/              реестр модулей MASHSTROY
│   │   └── SmartConveyor/
│   │       ├── Telemetry         телеметрия, режимы, нормы
│   │       ├── Commands          команды и ConveyorSafetyPolicy
│   │       ├── Hardware, Vision  ESP32, модули, события камеры
│   │       ├── ConveyorLink      граница приложение ↔ оборудование
│   │       ├── ConveyorSimulator симулятор ESP32 и неисправностей
│   │       ├── Diagnostics       ИИ-диагностика, здоровье, RUL
│   │       ├── FaultCenter       карточки аварий
│   │       └── History           периоды и статистика графиков
│   └── MashstroyUI/              SwiftUI-экраны
├── Tests/MashstroyCoreTests/
└── supabase/                     миграции, RLS, seed для MASHSTROY Cloud
```

## Публикация в App Store

Что уже готово в коде и что сделать вручную (аккаунт разработчика,
карточка, скриншоты, ответы о конфиденциальности, данные для ревьюера) —
в [`docs/APP_STORE_CHECKLIST.md`](docs/APP_STORE_CHECKLIST.md).
Политика конфиденциальности и условия (RU + EN) — в `docs/`.

## Облако (Supabase)

Схема базы, роли через RLS и демо-данные лежат в [`supabase/`](supabase/README.md).
Отдельный проект Supabase для MASHSTROY (`qpiweupinpkfmiitrbut`). Адрес
проекта записан в `Config/Base.xcconfig`, ключи в git не попадают.

Как включить облако:
1. Supabase → SQL Editor: выполнить по порядку файлы `supabase/migrations/`
   (0100…0500), затем `supabase/seed.sql`.
2. Скопировать `Config/Secrets.example.xcconfig` в `Config/Secrets.xcconfig`
   и вставить publishable key (`sb_publishable_…`). Secret key в приложение
   не кладётся никогда, приложение его отклонит.
3. Запустить приложение, зарегистрироваться, затем в SQL Editor:
   `select public.ms_bootstrap_owner('ваш@email', 'Ваше имя');`
4. Для быстрых тестов можно выключить подтверждение e-mail
   (Authentication → Sign In / Providers → Email → Confirm email).

Без ключа приложение работает в демо-режиме на симуляторе. С ключом вход
настоящий, машины, состояние, аварии и графики читаются из базы, команды
пишутся в таблицу `commands` и ждут подтверждения ESP32.

## Подключение ESP32

Приложение работает только через протокол `ConveyorLink`
(`poll`, `send`, `history`). Для реальной установки служит
`CloudConveyorLink` (модуль MashstroyCloud), который ходит в MASHSTROY Cloud:

```
Mobile App → MASHSTROY Cloud → Secure Gateway → ESP32 → Sensors / Actuators
```

Телефон не отправляет команды двигателю напрямую. `ConveyorSafetyPolicy`
проверяет команды в приложении, та же проверка повторяется в облаке и на
ESP32. Локальные защиты (ток, температура, вибрация, заклинивание,
крышка, аварийная кнопка) работают на контроллере без интернета, а
физическая кнопка Emergency Stop на машине остаётся основной.

## Что дальше

- Прошивка ESP32 и облако (MASHSTROY Cloud, Secure Gateway), реальный вход.
- Push-уведомления, отчёты, Digital Twin, AI Assistant, Research Mode,
  R&D Library, Projects, Pilot, Fleet, экран 90 DAYS.
- ML-модель диагностики, обученная на закрытых карточках Fault Center.
- Документ архитектуры: https://claude.ai/artifact/SNyHyzKiYh6ztAKWkBzqLh

## Как добавить новый модуль

1. Добавьте случай в `ModuleKind` и описание в `ModuleRegistry.descriptor(for:)`.
2. Создайте папку `Sources/MashstroyCore/<Модуль>/` по образцу Smart Conveyor.
3. Добавьте экраны в `Sources/MashstroyUI/`.
