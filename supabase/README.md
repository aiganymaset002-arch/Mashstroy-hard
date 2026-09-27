# MASHSTROY Cloud — база Supabase

Отдельный проект Supabase для MASHSTROY (не общий с KKSU).

## Схема

```
organizations ─┬─ sites ── machines ─┬─ components (узлы: health, RUL)
               │                     ├─ devices (ESP32)
               └─ members (роль,     ├─ sensors (метрика, нормы, порог защиты)
                  площадки)          ├─ telemetry (секции по месяцам)
                                     ├─ machine_state (снимок для Dashboard)
machine_types ── mode_presets        ├─ commands (путь команды с ack)
                                     ├─ alerts, anomalies
                                     ├─ faults ── fault_events
                                     └─ media (кадры и клипы камеры)
```

| Миграция | Что делает |
|---|---|
| `…0100_core_schema` | организации, площадки, участники, типы машин, режимы, машины, узлы, ESP32, датчики |
| `…0200_telemetry` | телеметрия по месяцам, `machine_state`, `media`, функция графиков `ms_telemetry_series` |
| `…0300_operations` | команды, предупреждения, аномалии ИИ, Fault Center с номерами `FAULT-ГГГГ-NNNNN` |
| `…0400_access_rules` | роли через RLS, `ms_acknowledge_alert`, `ms_bootstrap_owner`, Realtime |

`seed.sql` добавляет организацию MASHSTROY, площадку MASHSTROY Laboratory,
прототип MS-CNV-0001 с шестью узлами, ESP32, датчиками с нормами и четыре режима.

## Роли

| Роль | Видит | Команды | Fault Center |
|---|---|---|---|
| owner MASHSTROY | весь парк | все | да |
| owner организации | свою организацию | все | да |
| engineer | свои площадки | все | да |
| researcher | свои площадки | stop, emergency_stop | чтение |
| technician | свои площадки | stop, emergency_stop, reset_fault | да |
| client, viewer | своё оборудование | нет | чтение |
| intern | свои площадки | нет | чтение |

Телеметрию, состояние машины, аномалии и статусы команд пишет только облако
с service role. Пользователь может создать команду, но выполняет её шлюз
после проверки, а ESP32 — только если это безопасно.

В Fault Center пользователи меняют только статус, запись техника и найденную
причину. Статус идёт строго вперёд: new → accepted → repairing → resolved,
для resolved нужна запись техника. Каждое изменение пишется в `fault_events`.

## Как развернуть

1. Создайте проект на [supabase.com](https://supabase.com) (регион ближе к Казахстану, например Frankfurt).
2. Скопируйте `supabase/.env.example` в `supabase/.env` и впишите значения
   из Project Settings → API. Ключи в git не коммитьте.
3. Примените миграции одним из способов:
   - **Supabase CLI:** `supabase link --project-ref <ref>`, затем `supabase db push`,
     затем выполните `seed.sql` в SQL Editor;
   - **без CLI:** в SQL Editor выполните по порядку четыре файла из `migrations/`, затем `seed.sql`.
4. Зарегистрируйтесь (Authentication → Users → Add user или через приложение)
   и назначьте себя владельцем в SQL Editor:
   ```sql
   select public.ms_bootstrap_owner('ваш@email', 'Ваше имя');
   ```
5. Раз в месяц создавайте секцию телеметрии на следующий месяц
   (например, через pg_cron):
   ```sql
   select public.ms_ensure_telemetry_partition((now() + interval '1 month')::date);
   ```

Локально: `supabase start` применит миграции и `seed.sql` автоматически.

## Приложение

Адрес проекта задан в `Config/Base.xcconfig`. Publishable key
(`sb_publishable_…`) вставляется локально в `Config/Secrets.xcconfig`
(образец `Config/Secrets.example.xcconfig`, файл в git не попадает) и
через Info.plist доходит до `SupabaseConfig`. Переменные окружения схемы
Xcode `MASHSTROY_SUPABASE_URL` и `MASHSTROY_SUPABASE_PUBLISHABLE_KEY`
имеют приоритет. Secret key (`sb_secret_…`) в приложение не попадает
никогда: `SupabaseConfig` его отклоняет. Без ключа приложение работает в
демо-режиме на симуляторе.
