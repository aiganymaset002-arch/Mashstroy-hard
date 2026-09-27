-- Демо-данные: организация MASHSTROY, лаборатория и прототип Smart Conveyor MS-CNV-0001.
-- Нормы датчиков совпадают с NominalProfile в приложении; уточните их для реального прототипа.
-- Пользователей здесь нет: зарегистрируйтесь в приложении и выполните
--   select public.ms_bootstrap_owner('ваш@email');

insert into public.machine_types (code, name, components, commands) values
('smart_conveyor', 'Smart Conveyor',
 '[{"kind": "motor", "name": "Motor"},
   {"kind": "bearing1", "name": "Bearing #1"},
   {"kind": "bearing2", "name": "Bearing #2"},
   {"kind": "belt", "name": "Belt"},
   {"kind": "air_chamber", "name": "Air chamber"},
   {"kind": "press_actuator", "name": "Press actuator"}]',
 array['start', 'stop', 'pause', 'emergency_stop', 'reset_fault', 'set_speed', 'set_control_mode',
       'set_direction', 'set_fan', 'set_air_cushion', 'set_drive', 'set_hopper_feed', 'press_cycle', 'run_mode']),
('water_treatment', 'Очистка воды', '[]', '{}'),
('sludge_recycling', 'Переработка шлама', '[]', '{}'),
('lab_unit', 'Лабораторная установка', '[]', '{}')
on conflict (code) do nothing;

insert into public.mode_presets (machine_type, code, name, params) values
('smart_conveyor', 'eco_brick', 'Mode 1 — Eco Brick', '{"speed": 0.8, "load_kg": 32, "press": true}'),
('smart_conveyor', 'sludge_processing', 'Mode 2 — Sludge Processing', '{"speed": 0.6, "load_kg": 40}'),
('smart_conveyor', 'material_transport', 'Mode 3 — Material Transport', '{"speed": 1.2, "load_kg": 30}'),
('smart_conveyor', 'research', 'Mode 4 — Testing / Research', '{"speed": 0.5, "load_kg": 12}')
on conflict (machine_type, code) do nothing;

insert into public.organizations (id, name, kind) values
('00000000-0000-4000-8000-000000000001', 'MASHSTROY', 'mashstroy')
on conflict do nothing;

insert into public.sites (id, org_id, name, location) values
('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'MASHSTROY Laboratory', 'Казахстан')
on conflict (id) do nothing;

insert into public.machines (id, serial, type, site_id, name, firmware, commissioned_at) values
('00000000-0000-4000-8000-000000001001', 'MS-CNV-0001', 'smart_conveyor', '00000000-0000-4000-8000-000000000101',
 'Smart Conveyor — прототип V1', '1.4.2', '2026-09-01')
on conflict (serial) do nothing;

insert into public.components (machine_id, kind, name, health)
select '00000000-0000-4000-8000-000000001001', c->>'kind', c->>'name', 100
from public.machine_types t, jsonb_array_elements(t.components) c
where t.code = 'smart_conveyor'
on conflict (machine_id, kind) do nothing;

insert into public.devices (machine_id, kind, device_id, fw_version, wifi_ssid) values
('00000000-0000-4000-8000-000000001001', 'esp32_main', 'ESP32-3C71BF4A2E10', '1.4.2', 'MASHSTROY-LAB')
on conflict (device_id) do nothing;

insert into public.sensors (machine_id, device_id, component_id, metric, unit, normal_min, normal_max, trip_max)
select m.id, d.id, c.id, s.metric, s.unit, s.normal_min, s.normal_max, s.trip_max
from (values
    ('beltSpeed',           'm/s',  0.2,  2.0,  null::double precision, 'belt'),
    ('motorRPM',            'rpm',  null, null, null, 'motor'),
    ('current',             'A',    2.8,  3.6,  6.0,  'motor'),
    ('voltage',             'V',    23.0, 25.0, null, 'motor'),
    ('power',               'W',    null, null, null, 'motor'),
    ('load',                'kg',   0,    50,   null, 'belt'),
    ('airPressure',         'kPa',  4.5,  6.0,  null, 'air_chamber'),
    ('motorTemperature',    '°C',   null, 75,   90,   'motor'),
    ('bearing1Temperature', '°C',   null, 65,   null, 'bearing1'),
    ('bearing2Temperature', '°C',   null, 65,   null, 'bearing2'),
    ('vibration',           'mm/s', null, 3.5,  7.1,  'bearing2'),
    ('throughput',          'kg/h', null, null, null, 'belt'),
    ('beltOffset',          'mm',   -10,  10,   null, 'belt'),
    ('pressPosition',       '%',    0,    100,  null, 'press_actuator')
) as s (metric, unit, normal_min, normal_max, trip_max, component_kind)
join public.machines m on m.serial = 'MS-CNV-0001'
join public.devices d on d.machine_id = m.id and d.kind = 'esp32_main'
left join public.components c on c.machine_id = m.id and c.kind = s.component_kind
on conflict (machine_id, metric) do nothing;

insert into public.machine_state (machine_id, state, mode, control_mode, direction, speed, speed_setpoint)
values ('00000000-0000-4000-8000-000000001001', 'OFFLINE', 'material_transport', 'manual', 'forward', 0, 1.2)
on conflict (machine_id) do nothing;
