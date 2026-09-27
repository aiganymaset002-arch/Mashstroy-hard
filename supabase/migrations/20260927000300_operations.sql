-- Команды, предупреждения, аномалии ИИ и Fault Center.

-- ---------------------------------------------------------------------------
-- Команды: приложение создаёт запись, облако проверяет и подписывает,
-- шлюз передаёт ESP32, ESP32 отвечает ack. Статус меняет только сервер.
-- ---------------------------------------------------------------------------
create table public.commands (
    id             uuid primary key default gen_random_uuid(),
    machine_id     uuid not null references public.machines (id) on delete cascade,
    user_id        uuid not null default auth.uid() references auth.users (id),
    action         text not null check (action in (
                       'start', 'stop', 'pause', 'emergency_stop', 'reset_fault', 'set_speed',
                       'set_control_mode', 'set_direction', 'set_fan', 'set_air_cushion', 'set_drive',
                       'set_hopper_feed', 'press_cycle', 'run_mode')),
    params         jsonb not null default '{}',
    status         public.ms_command_status not null default 'pending',
    reject_reason  text,
    created_at     timestamptz not null default now(),
    expires_at     timestamptz not null default now() + interval '10 seconds',
    acked_at       timestamptz
);

create index commands_machine_created_idx on public.commands (machine_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Предупреждения (уходят push-уведомлениями)
-- ---------------------------------------------------------------------------
create table public.alerts (
    id               bigint generated always as identity primary key,
    machine_id       uuid not null references public.machines (id) on delete cascade,
    severity         public.ms_risk not null,
    metric           text,
    message          text not null,
    ts               timestamptz not null default now(),
    acknowledged_by  uuid references auth.users (id),
    acknowledged_at  timestamptz
);

create index alerts_machine_ts_idx on public.alerts (machine_id, ts desc);

-- ---------------------------------------------------------------------------
-- Аномалии: что произошло → причина → вероятность → что проверить → срочность
-- ---------------------------------------------------------------------------
create table public.anomalies (
    id            uuid primary key default gen_random_uuid(),
    machine_id    uuid not null references public.machines (id) on delete cascade,
    component_id  uuid references public.components (id) on delete set null,
    kind          text not null,
    signals       jsonb not null default '[]',
    diagnosis     text not null,
    cause         text,
    confidence    numeric(4, 3) check (confidence between 0 and 1),
    urgency       public.ms_risk not null,
    checks        text[] not null default '{}',
    created_at    timestamptz not null default now()
);

create index anomalies_machine_created_idx on public.anomalies (machine_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Fault Center. Связка anomaly → fault → root_cause — датасет для обучения ИИ.
-- ---------------------------------------------------------------------------
create table public.fault_counters (
    year  integer primary key,
    last  integer not null
);

create table public.faults (
    id               uuid primary key default gen_random_uuid(),
    code             text not null unique,
    machine_id       uuid not null references public.machines (id) on delete cascade,
    component_id     uuid references public.components (id) on delete set null,
    anomaly_id       uuid references public.anomalies (id) on delete set null,
    kind             text not null,
    detected_at      timestamptz not null default now(),
    title            text not null,
    measured         text,
    normal           text,
    snapshot         jsonb not null default '{}',
    ai_diagnosis     text,
    probability      numeric(4, 3) check (probability between 0 and 1),
    risk             public.ms_risk not null,
    action           text,
    status           public.ms_fault_status not null default 'new',
    technician_note  text,
    root_cause       text,
    updated_at       timestamptz not null default now()
);

create index faults_machine_status_idx on public.faults (machine_id, status, detected_at desc);

create table public.fault_events (
    id          bigint generated always as identity primary key,
    fault_id    uuid not null references public.faults (id) on delete cascade,
    status      public.ms_fault_status not null,
    note        text not null default '',
    user_id     uuid references auth.users (id),
    created_at  timestamptz not null default now()
);

create index fault_events_fault_idx on public.fault_events (fault_id, created_at);

-- Номер FAULT-ГГГГ-NNNNN, отдельный счётчик на каждый год.
create or replace function public.ms_next_fault_code(p_at timestamptz default now())
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    y integer := extract(year from p_at)::integer;
    n integer;
begin
    insert into public.fault_counters as fc (year, last) values (y, 1)
    on conflict (year) do update set last = fc.last + 1
    returning last into n;
    return format('FAULT-%s-%s', y, lpad(n::text, 5, '0'));
end;
$$;

revoke execute on function public.ms_next_fault_code(timestamptz) from public, anon, authenticated;

create or replace function public.ms_fault_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.code is null or new.code = '' then
        new.code := public.ms_next_fault_code(coalesce(new.detected_at, now()));
    end if;
    new.status := 'new';
    return new;
end;
$$;

-- Статус идёт только вперёд: new → accepted → repairing → resolved.
-- Для resolved нужна запись техника. Пользователи меняют только статус,
-- запись техника и найденную причину; остальное — снимок ИИ.
create or replace function public.ms_fault_before_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    order_old integer := array_position(enum_range(null::public.ms_fault_status), old.status);
    order_new integer := array_position(enum_range(null::public.ms_fault_status), new.status);
begin
    if coalesce(auth.role(), '') <> 'service_role' then
        new.code := old.code;
        new.machine_id := old.machine_id;
        new.component_id := old.component_id;
        new.anomaly_id := old.anomaly_id;
        new.kind := old.kind;
        new.detected_at := old.detected_at;
        new.title := old.title;
        new.measured := old.measured;
        new.normal := old.normal;
        new.snapshot := old.snapshot;
        new.ai_diagnosis := old.ai_diagnosis;
        new.probability := old.probability;
        new.risk := old.risk;
        new.action := old.action;
    end if;

    if new.status is distinct from old.status then
        if order_new <> order_old + 1 then
            raise exception 'Недопустимый переход статуса: % → %', old.status, new.status;
        end if;
        if new.status = 'resolved' and coalesce(btrim(new.technician_note), '') = '' then
            raise exception 'Опишите, что реально было неисправно';
        end if;
    end if;

    new.updated_at := now();
    return new;
end;
$$;

create or replace function public.ms_fault_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        insert into public.fault_events (fault_id, status, note, user_id)
        values (new.id, new.status, 'Обнаружено ИИ', auth.uid());
    elsif new.status is distinct from old.status then
        insert into public.fault_events (fault_id, status, note, user_id)
        values (new.id, new.status, coalesce(new.technician_note, ''), auth.uid());
    end if;
    return null;
end;
$$;

create trigger faults_before_insert before insert on public.faults
    for each row execute function public.ms_fault_before_insert();
create trigger faults_before_update before update on public.faults
    for each row execute function public.ms_fault_before_update();
create trigger faults_log after insert or update on public.faults
    for each row execute function public.ms_fault_log();
