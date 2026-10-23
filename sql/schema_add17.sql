-- 앱 설정 (지금은 시험 문제 유형 목록 exam_types). 누구나 읽을 수 있고, 바꾸기는 강사만
create table if not exists app_settings (
  key text primary key,
  value jsonb,
  updated_at timestamptz default now()
);
alter table app_settings enable row level security;
revoke all on app_settings from anon, authenticated;
grant select on app_settings to anon, authenticated;
drop policy if exists "public read" on app_settings;
create policy "public read" on app_settings for select using (true);

create or replace function teacher_setting_set(p_token text, p_key text, p_value jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  insert into app_settings(key, value, updated_at) values (p_key, p_value, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
  return null;
end $$;
grant execute on function teacher_setting_set(text, text, jsonb) to anon, authenticated;
