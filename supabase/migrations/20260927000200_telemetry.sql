-- Телеметрия и снимок состояния для Dashboard.
-- Сырые данные пишет облако (service role) из шлюза; приложение только читает.

create table public.telemetry (
    machine_id  uuid not null references public.machines (id) on delete cascade,
    sensor_id   uuid not null references public.sensors (id) on delete cascade,
    ts          timestamptz not null,
    value       double precision not null,
    primary key (sensor_id, ts)
) partition by range (ts);

create table public.telemetry_default partition of public.telemetry default;

create index telemetry_machine_ts_idx on public.telemetry (machine_id, ts desc);

-- Создаёт месячную секцию telemetry_yYYYYmMM, если её ещё нет.
-- Вызывайте раз в месяц (pg_cron или фоновая задача облака).
create or replace function public.ms_ensure_telemetry_partition(p_month date)
returns text
language plpgsql
set search_path = public
as $$
declare
    start_ts date := date_trunc('month', p_month)::date;
    end_ts   date := (date_trunc('month', p_month) + interval '1 month')::date;
    part     text := format('telemetry_y%sm%s', to_char(start_ts, 'YYYY'), to_char(start_ts, 'MM'));
begin
    if to_regclass('public.' || part) is null then
        execute format('create table public.%I partition of public.telemetry for values from (%L) to (%L)',
                       part, start_ts, end_ts);
        -- Без политик: прямое чтение секции запрещено, данные видны только через telemetry.
        execute format('alter table public.%I enable row level security', part);
    end if;
    return part;
end;
$$;

revoke execute on function public.ms_ensure_telemetry_partition(date) from public, anon, authenticated;

select public.ms_ensure_telemetry_partition((date_trunc('month', now()) + make_interval(months => m))::date)
from generate_series(0, 2) as m;

create table public.machine_state (
    machine_id         uuid primary key references public.machines (id) on delete cascade,
    ts                 timestamptz not null default now(),
    state              public.ms_machine_state not null default 'OFFLINE',
    trip_reason        text,
    mode               text,
    control_mode       text,
    direction          text,
    speed              double precision,
    speed_setpoint     double precision,
    cycles             integer not null default 0,
    uptime_s           bigint not null default 0,
    controller_online  boolean not null default false,
    -- Последние значения всех датчиков: {"current": 3.2, "vibration": 2.3, ...}
    snapshot           jsonb not null default '{}'
);

-- Кадры и клипы событий с камеры (видео через MQTT не идёт).
create table public.media (
    id          uuid primary key default gen_random_uuid(),
    machine_id  uuid not null references public.machines (id) on delete cascade,
    kind        text not null check (kind in ('frame', 'clip', 'photo')),
    url         text not null,
    ts          timestamptz not null default now(),
    cv_labels   jsonb not null default '[]'
);

create index media_machine_ts_idx on public.media (machine_id, ts desc);

-- Ряд для графиков: min / max / avg по интервалам (1 мин, 1 ч, …).
-- security invoker: работают правила доступа вызывающего.
create or replace function public.ms_telemetry_series(
    p_machine uuid, p_metric text, p_from timestamptz, p_to timestamptz, p_bucket interval)
returns table (bucket timestamptz, min_value double precision, max_value double precision, avg_value double precision)
language sql
stable
security invoker
set search_path = public
as $$
    select date_bin(p_bucket, t.ts, timestamptz '2000-01-01') as bucket,
           min(t.value), max(t.value), avg(t.value)
    from public.telemetry t
    join public.sensors s on s.id = t.sensor_id
    where t.machine_id = p_machine
      and s.metric = p_metric
      and t.ts >= p_from and t.ts < p_to
    group by 1
    order by 1
$$;
