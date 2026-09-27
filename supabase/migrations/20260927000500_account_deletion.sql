-- Удаление аккаунта из приложения (App Store Review Guideline 5.1.1(v)).
-- Журналы команд, аварий и предупреждений остаются для безопасности и
-- расследования инцидентов, но теряют связь с удалённым пользователем.

alter table public.commands alter column user_id drop not null;
alter table public.commands drop constraint commands_user_id_fkey;
alter table public.commands add constraint commands_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete set null;

alter table public.alerts drop constraint alerts_acknowledged_by_fkey;
alter table public.alerts add constraint alerts_acknowledged_by_fkey
    foreign key (acknowledged_by) references auth.users (id) on delete set null;

alter table public.fault_events drop constraint fault_events_user_id_fkey;
alter table public.fault_events add constraint fault_events_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete set null;

-- Удаляет аккаунт вызывающего пользователя. Участие в организациях
-- (members) удаляется каскадно вместе с auth.users.
create or replace function public.ms_delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user uuid := auth.uid();
begin
    if v_user is null then
        raise exception 'Нужно войти в аккаунт';
    end if;
    delete from auth.users where id = v_user;
end;
$$;

revoke execute on function public.ms_delete_my_account() from public, anon;
grant execute on function public.ms_delete_my_account() to authenticated;
