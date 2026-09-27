-- MASHSTROY AI Control — основная схема.
-- Организация → площадка → машина → узел → датчик. Тип машины задаёт узлы,
-- датчики, команды и режимы, поэтому новая установка — новые строки, а не код.

create extension if not exists pgcrypto;

create type public.ms_role as enum ('owner', 'engineer', 'researcher', 'technician', 'client', 'intern', 'viewer');
create type public.ms_org_kind as enum ('mashstroy', 'client');
create type public.ms_machine_state as enum ('RUNNING', 'PAUSED', 'STOPPED', 'WARNING', 'FAULT', 'EMERGENCY', 'OFFLINE');
create type public.ms_risk as enum ('low', 'medium', 'high', 'critical');
create type public.ms_fault_status as enum ('new', 'accepted', 'repairing', 'resolved');
create type public.ms_command_status as enum ('pending', 'rejected', 'sent', 'executed', 'failed', 'expired');

-- ---------------------------------------------------------------------------
-- Организации, площадки, участники
-- ---------------------------------------------------------------------------
create table public.organizations (
    id          uuid primary key default gen_random_uuid(),
    name        text not null,
    kind        public.ms_org_kind not null default 'client',
    created_at  timestamptz not null default now()
);

-- Организация MASHSTROY может быть только одна: её владельцы видят весь парк.
create unique index organizations_single_mashstroy on public.organizations (kind) where kind = 'mashstroy';

create table public.sites (
    id          uuid primary key default gen_random_uuid(),
    org_id      uuid not null references public.organizations (id) on delete cascade,
    name        text not null,
    location    text,
    created_at  timestamptz not null default now()
);

create table public.members (
    user_id     uuid not null references auth.users (id) on delete cascade,
    org_id      uuid not null references public.organizations (id) on delete cascade,
    role        public.ms_role not null,
    full_name   text not null default '',
    -- null — все площадки организации, иначе только перечисленные.
    site_ids    uuid[],
    blocked     boolean not null default false,
    created_at  timestamptz not null default now(),
    primary key (user_id, org_id)
);

-- ---------------------------------------------------------------------------
-- Типы машин и режимы
-- ---------------------------------------------------------------------------
create table public.machine_types (
    code        text primary key,
    name        text not null,
    -- [{"kind": "bearing2", "name": "Bearing #2"}, ...]
    components  jsonb not null default '[]',
    commands    text[] not null default '{}',
    created_at  timestamptz not null default now()
);

create table public.mode_presets (
    id            uuid primary key default gen_random_uuid(),
    machine_type  text not null references public.machine_types (code) on delete cascade,
    code          text not null,
    name          text not null,
    params        jsonb not null default '{}',
    unique (machine_type, code)
);

-- ---------------------------------------------------------------------------
-- Машины, узлы, электроника, датчики
-- ---------------------------------------------------------------------------
create table public.machines (
    id               uuid primary key default gen_random_uuid(),
    serial           text not null unique,
    type             text not null references public.machine_types (code),
    site_id          uuid not null references public.sites (id) on delete restrict,
    name             text not null default '',
    firmware         text,
    commissioned_at  date,
    created_at       timestamptz not null default now()
);

create table public.components (
    id                     uuid primary key default gen_random_uuid(),
    machine_id             uuid not null references public.machines (id) on delete cascade,
    kind                   text not null,
    name                   text not null,
    health                 numeric(5, 2) check (health between 0 and 100),
    rul_hours              numeric,
    rul_uncertainty_hours  numeric,
    operating_hours        numeric not null default 0,
    updated_at             timestamptz not null default now(),
    unique (machine_id, kind)
);

create table public.devices (
    id          uuid primary key default gen_random_uuid(),
    machine_id  uuid not null references public.machines (id) on delete cascade,
    kind        text not null,
    device_id   text not null unique,
    fw_version  text,
    ip          inet,
    wifi_ssid   text,
    rssi        integer,
    last_seen   timestamptz
);

create table public.sensors (
    id            uuid primary key default gen_random_uuid(),
    machine_id    uuid not null references public.machines (id) on delete cascade,
    device_id     uuid references public.devices (id) on delete set null,
    component_id  uuid references public.components (id) on delete set null,
    metric        text not null,
    unit          text not null,
    normal_min    double precision,
    normal_max    double precision,
    -- Порог локальной защиты ESP32 (справочно; срабатывает на контроллере).
    trip_max      double precision,
    unique (machine_id, metric)
);

create index sites_org_idx on public.sites (org_id);
create index members_org_idx on public.members (org_id);
create index machines_site_idx on public.machines (site_id);
create index components_machine_idx on public.components (machine_id);
create index devices_machine_idx on public.devices (machine_id);
create index sensors_machine_idx on public.sensors (machine_id);
