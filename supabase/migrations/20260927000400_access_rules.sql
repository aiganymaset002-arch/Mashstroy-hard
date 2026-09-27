-- Роли и правила доступа (RLS).
--
-- Кто что видит:
--   • участник организации видит машины её площадок (или только site_ids, если заданы);
--   • владелец (owner) организации MASHSTROY видит и администрирует весь парк;
--   • сырые данные (телеметрия, состояние, аномалии, статусы команд) пишет только
--     облако с service role — у приложения нет прав на запись в них.
-- Кто чем управляет (совпадает с ConveyorSafetyPolicy и ролями приложения):
--   • owner, engineer — все команды;
--   • researcher, technician — stop, emergency_stop, reset_fault (technician);
--   • client, intern, viewer — только просмотр.

-- ---------------------------------------------------------------------------
-- Помощники (security definer — чтобы политики не зацикливались)
-- ---------------------------------------------------------------------------
create or replace function public.ms_is_global_owner()
returns boolean
language sql stable security definer set search_path = public
as $$
    select exists (
        select 1 from public.members m
        join public.organizations o on o.id = m.org_id
        where m.user_id = auth.uid() and not m.blocked
          and o.kind = 'mashstroy' and m.role = 'owner')
$$;

create or replace function public.ms_is_org_owner(p_org uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select public.ms_is_global_owner() or exists (
        select 1 from public.members m
        where m.user_id = auth.uid() and m.org_id = p_org and not m.blocked and m.role = 'owner')
$$;

create or replace function public.ms_can_view_site(p_site uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select public.ms_is_global_owner() or exists (
        select 1 from public.members m
        join public.sites s on s.org_id = m.org_id
        where s.id = p_site and m.user_id = auth.uid() and not m.blocked
          and (m.site_ids is null or s.id = any (m.site_ids)))
$$;

-- Самая сильная роль пользователя для машины (null — нет доступа).
create or replace function public.ms_role_for_machine(p_machine uuid)
returns public.ms_role
language sql stable security definer set search_path = public
as $$
    select role from (
        select 'owner'::public.ms_role as role
        where public.ms_is_global_owner()
        union all
        select m.role
        from public.members m
        join public.sites s on s.org_id = m.org_id
        join public.machines mc on mc.site_id = s.id
        where mc.id = p_machine and m.user_id = auth.uid() and not m.blocked
          and (m.site_ids is null or s.id = any (m.site_ids))
    ) r
    order by array_position(enum_range(null::public.ms_role), r.role)
    limit 1
$$;

create or replace function public.ms_can_view_machine(p_machine uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select public.ms_role_for_machine(p_machine) is not null
$$;

create or replace function public.ms_can_configure_machine(p_machine uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select coalesce(public.ms_role_for_machine(p_machine) in ('owner', 'engineer'), false)
$$;

create or replace function public.ms_can_manage_faults(p_machine uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select coalesce(public.ms_role_for_machine(p_machine) in ('owner', 'engineer', 'technician'), false)
$$;

create or replace function public.ms_command_allowed(p_machine uuid, p_action text)
returns boolean
language sql stable security definer set search_path = public
as $$
    select case public.ms_role_for_machine(p_machine)
        when 'owner' then true
        when 'engineer' then true
        when 'technician' then p_action in ('stop', 'emergency_stop', 'reset_fault')
        when 'researcher' then p_action in ('stop', 'emergency_stop')
        else false
    end
$$;

-- ---------------------------------------------------------------------------
-- Включаем RLS везде
-- ---------------------------------------------------------------------------
alter table public.organizations  enable row level security;
alter table public.sites          enable row level security;
alter table public.members        enable row level security;
alter table public.machine_types  enable row level security;
alter table public.mode_presets   enable row level security;
alter table public.machines       enable row level security;
alter table public.components     enable row level security;
alter table public.devices        enable row level security;
alter table public.sensors        enable row level security;
alter table public.telemetry      enable row level security;
-- Секции таблицы телеметрии тоже закрыты: читать можно только через telemetry.
alter table public.telemetry_default enable row level security;
alter table public.machine_state  enable row level security;
alter table public.media          enable row level security;
alter table public.commands       enable row level security;
alter table public.alerts         enable row level security;
alter table public.anomalies      enable row level security;
alter table public.fault_counters enable row level security;
alter table public.faults         enable row level security;
alter table public.fault_events   enable row level security;

-- Организации и площадки
create policy organizations_select on public.organizations for select to authenticated
    using (public.ms_is_global_owner()
           or exists (select 1 from public.members m where m.org_id = organizations.id and m.user_id = auth.uid() and not m.blocked));
create policy organizations_insert on public.organizations for insert to authenticated
    with check (public.ms_is_global_owner() and kind = 'client');
create policy organizations_update on public.organizations for update to authenticated
    using (public.ms_is_org_owner(id)) with check (public.ms_is_org_owner(id));

create policy sites_select on public.sites for select to authenticated
    using (public.ms_can_view_site(id));
create policy sites_write on public.sites for all to authenticated
    using (public.ms_is_org_owner(org_id)) with check (public.ms_is_org_owner(org_id));

-- Участники: видят себя; владелец организации видит и назначает участников.
create policy members_select on public.members for select to authenticated
    using (user_id = auth.uid() or public.ms_is_org_owner(org_id));
create policy members_write on public.members for all to authenticated
    using (public.ms_is_org_owner(org_id)) with check (public.ms_is_org_owner(org_id));

-- Справочники читают все вошедшие, меняет только сервер.
create policy machine_types_select on public.machine_types for select to authenticated using (true);
create policy mode_presets_select on public.mode_presets for select to authenticated using (true);

-- Машины и их состав
create policy machines_select on public.machines for select to authenticated
    using (public.ms_can_view_machine(id));
create policy machines_insert on public.machines for insert to authenticated
    with check (public.ms_is_org_owner((select s.org_id from public.sites s where s.id = site_id)));
create policy machines_update on public.machines for update to authenticated
    using (public.ms_can_configure_machine(id))
    with check (public.ms_is_org_owner((select s.org_id from public.sites s where s.id = site_id))
                or public.ms_can_configure_machine(id));
create policy machines_delete on public.machines for delete to authenticated
    using (public.ms_is_org_owner((select s.org_id from public.sites s where s.id = site_id)));

create policy components_select on public.components for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy components_write on public.components for all to authenticated
    using (public.ms_can_configure_machine(machine_id)) with check (public.ms_can_configure_machine(machine_id));

create policy devices_select on public.devices for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy devices_write on public.devices for all to authenticated
    using (public.ms_can_configure_machine(machine_id)) with check (public.ms_can_configure_machine(machine_id));

create policy sensors_select on public.sensors for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy sensors_write on public.sensors for all to authenticated
    using (public.ms_can_configure_machine(machine_id)) with check (public.ms_can_configure_machine(machine_id));

-- Данные с оборудования: только чтение.
create policy telemetry_select on public.telemetry for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy machine_state_select on public.machine_state for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy media_select on public.media for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy anomalies_select on public.anomalies for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy alerts_select on public.alerts for select to authenticated
    using (public.ms_can_view_machine(machine_id));

-- Команды: пользователь создаёт только свои и только разрешённые его роли.
create policy commands_select on public.commands for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy commands_insert on public.commands for insert to authenticated
    with check (user_id = auth.uid()
                and status = 'pending'
                and acked_at is null
                and expires_at <= now() + interval '30 seconds'
                and public.ms_command_allowed(machine_id, action));

-- Fault Center
create policy faults_select on public.faults for select to authenticated
    using (public.ms_can_view_machine(machine_id));
create policy faults_insert on public.faults for insert to authenticated
    with check (public.ms_can_manage_faults(machine_id));
create policy faults_update on public.faults for update to authenticated
    using (public.ms_can_manage_faults(machine_id)) with check (public.ms_can_manage_faults(machine_id));

create policy fault_events_select on public.fault_events for select to authenticated
    using (exists (select 1 from public.faults f where f.id = fault_id and public.ms_can_view_machine(f.machine_id)));

-- fault_counters: без политик, доступ только через ms_next_fault_code.

-- ---------------------------------------------------------------------------
-- Действия через функции
-- ---------------------------------------------------------------------------

-- Подтвердить предупреждение (все, кроме client, intern, viewer).
create or replace function public.ms_acknowledge_alert(p_alert bigint)
returns void
language plpgsql security definer set search_path = public
as $$
declare
    v_machine uuid;
begin
    select machine_id into v_machine from public.alerts where id = p_alert;
    if v_machine is null then
        raise exception 'Предупреждение не найдено';
    end if;
    if coalesce(public.ms_role_for_machine(v_machine) in ('owner', 'engineer', 'researcher', 'technician'), false) is false then
        raise exception 'Недостаточно прав';
    end if;
    update public.alerts
    set acknowledged_by = auth.uid(), acknowledged_at = now()
    where id = p_alert and acknowledged_at is null;
end;
$$;

revoke execute on function public.ms_acknowledge_alert(bigint) from public, anon;
grant execute on function public.ms_acknowledge_alert(bigint) to authenticated;

-- Назначить первого владельца MASHSTROY. Запускается один раз из SQL Editor
-- (под postgres), после того как владелец зарегистрировался в приложении.
create or replace function public.ms_bootstrap_owner(p_email text, p_full_name text default '')
returns void
language plpgsql security definer set search_path = public
as $$
declare
    v_user uuid;
    v_org  uuid;
begin
    select id into v_user from auth.users where lower(email) = lower(p_email);
    if v_user is null then
        raise exception 'Пользователь % не найден: сначала зарегистрируйтесь', p_email;
    end if;
    select id into v_org from public.organizations where kind = 'mashstroy';
    if v_org is null then
        insert into public.organizations (name, kind) values ('MASHSTROY', 'mashstroy') returning id into v_org;
    end if;
    insert into public.members (user_id, org_id, role, full_name)
    values (v_user, v_org, 'owner', p_full_name)
    on conflict (user_id, org_id) do update set role = 'owner', blocked = false;
end;
$$;

revoke execute on function public.ms_bootstrap_owner(text, text) from public, anon, authenticated;

-- Помощники нужны политикам, но не должны вызываться анонимно.
revoke execute on function public.ms_is_global_owner() from public, anon;
revoke execute on function public.ms_is_org_owner(uuid) from public, anon;
revoke execute on function public.ms_can_view_site(uuid) from public, anon;
revoke execute on function public.ms_role_for_machine(uuid) from public, anon;
revoke execute on function public.ms_can_view_machine(uuid) from public, anon;
revoke execute on function public.ms_can_configure_machine(uuid) from public, anon;
revoke execute on function public.ms_can_manage_faults(uuid) from public, anon;
revoke execute on function public.ms_command_allowed(uuid, text) from public, anon;
grant execute on function public.ms_is_global_owner() to authenticated;
grant execute on function public.ms_is_org_owner(uuid) to authenticated;
grant execute on function public.ms_can_view_site(uuid) to authenticated;
grant execute on function public.ms_role_for_machine(uuid) to authenticated;
grant execute on function public.ms_can_view_machine(uuid) to authenticated;
grant execute on function public.ms_can_configure_machine(uuid) to authenticated;
grant execute on function public.ms_can_manage_faults(uuid) to authenticated;
grant execute on function public.ms_command_allowed(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: живые данные для Dashboard, предупреждения и аварии
-- ---------------------------------------------------------------------------
do $$
begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        alter publication supabase_realtime add table public.machine_state, public.alerts, public.faults, public.commands;
    end if;
end;
$$;
