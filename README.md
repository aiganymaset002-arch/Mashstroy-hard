# MASHSTROY AI Control

Промышленное приложение для управления оборудованием MASHSTROY на базе ИИ.
Первый модуль — **Smart Conveyor**. Код оформлен как Swift Package (SwiftUI).

## Что уже есть

- **Дашборд Smart Conveyor**: статус линии, скорость, загрузка, температура
  двигателя, вибрация, график загрузки, аварии и рекомендации ИИ, индекс
  здоровья 0…100. Данные обновляются раз в секунду.
- **ИИ-движок** (`ConveyorAIEngine`): прозрачные правила по телеметрии и её
  тренду (перегруз, недогруз, перегрев и рост температуры, вибрация, сход
  ленты). За протоколом `ConveyorAnalyzing` его можно заменить на ML-модель.
- **Симулятор** (`SimulatedConveyorSource`): реалистичная телеметрия, пока
  нет подключения к контроллеру. Реальный источник реализует `ConveyorDataSource`.
- **Реестр модулей** (`ModuleRegistry`): Smart Conveyor активен; очистка воды,
  переработка шлама и лабораторные установки заведены как «скоро».

## Структура

```
mashstroy-hard/
├── App/                          iOS-приложение (Xcode-проект)
├── Package.swift
├── Sources/
│   ├── MashstroyCore/            логика без UI (тестируется)
│   │   ├── Modules/              реестр модулей
│   │   └── SmartConveyor/        модели, ИИ-движок, источник данных
│   └── MashstroyUI/              SwiftUI-экраны
│       ├── MashstroyRootView     список модулей
│       └── SmartConveyor…        дашборд конвейера
└── Tests/MashstroyCoreTests/
```

## Как запустить

1. Откройте `App/MashstroyAIControl.xcodeproj` в Xcode 15 или новее.
2. Выберите схему **MashstroyAIControl** и симулятор iPhone, нажмите ▶︎ (⌘R).
3. Для запуска на своём iPhone: Signing & Capabilities → выберите свою Team.

Тесты: `swift test` в корне репозитория (или ⌘U в Xcode).

## Как добавить новый модуль

1. Добавьте случай в `ModuleKind` и описание в `ModuleRegistry.all`.
2. Создайте папку `Sources/MashstroyCore/<Модуль>/` с моделями, источником
   данных и анализатором по образцу Smart Conveyor.
3. Добавьте экран в `Sources/MashstroyUI/` и ветку в
   `MashstroyRootView.destination(for:)`.

## Следующие шаги

- Подключение реального контроллера конвейера (OPC UA / Modbus через шлюз).
- Хранение телеметрии и аварий в облаке (Supabase).
- Роли: оператор, мастер смены, инженер.
- Документ архитектуры: https://claude.ai/artifact/SNyHyzKiYh6ztAKWkBzqLh
