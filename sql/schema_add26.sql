-- ============================================================
-- 정말 쏠쏠한 국어 — 클리닉 신청 (schema_add26, 2026-11-11)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요. 두 번 실행해도 괜찮아요.
-- ============================================================
-- 시간대(clinic_slots): 학생 화면에 보여야 해서 읽기는 누구나, 만들기·지우기는 강사 함수로만
-- 신청·지정(clinic_bookings): 사이트에서 직접 읽거나 쓸 수 없고 서버 함수로만
--   학생은 자리 수와 자기 신청만, 강사는 전체 명단

create table if not exists clinic_slots (
  id text primary key,
  date date not null,
  start_time text not null,          -- '17:00'
  end_time text,                     -- '18:00' (비워도 됨)
  capacity int,                      -- 정원 (비우면 제한 없음)
  targets text,                      -- 대상 학교 ["풍덕고"] (비우면 전체)
  note text,                         -- 안내 (장소 등)
  created_at timestamptz default now()
);
create table if not exists clinic_bookings (
  id text primary key,
  slot_id text not null references clinic_slots(id) on delete cascade,
  student_id text not null,
  memo text,                         -- (자율) 무엇을 도와줄까
  created_at timestamptz default now(),
  unique (slot_id, student_id)
);
-- 두 종류: self = 학생이 스스로 신청 / assigned = 쏠T가 지정(학생은 확인 또는 못 오는 사유만)
alter table clinic_bookings add column if not exists kind text not null default 'self';
alter table clinic_bookings add column if not exists reason text;            -- (지정) 쏠T가 적은 사유, 학생에게 보임
alter table clinic_bookings add column if not exists confirmed_at timestamptz; -- (지정) 학생이 '확인했어요'
alter table clinic_bookings add column if not exists decline_reason text;     -- (지정) 학생이 적은 못 오는 사유

revoke all on clinic_bookings from anon, authenticated;
revoke insert, update, delete on clinic_slots from anon, authenticated;
grant select on clinic_slots to anon, authenticated;

-- 한국 시각으로 그 시간대가 시작했는지
create or replace function clinic_started(s clinic_slots)
returns boolean language sql stable as $$
  select (s.date + s.start_time::time) <= (now() at time zone 'Asia/Seoul');
$$;

-- ---------- 강사 ----------
create or replace function teacher_clinic_slot_save(p_token text, p_row jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  insert into clinic_slots(id, date, start_time, end_time, capacity, targets, note)
  values (p_row->>'id', (p_row->>'date')::date, p_row->>'start_time', nullif(p_row->>'end_time', ''),
          nullif(p_row->>'capacity', '')::int, nullif(p_row->>'targets', ''), nullif(p_row->>'note', ''))
  on conflict (id) do update set date = excluded.date, start_time = excluded.start_time, end_time = excluded.end_time,
    capacity = excluded.capacity, targets = excluded.targets, note = excluded.note;
  return null;
end $$;

create or replace function teacher_clinic_slot_delete(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  delete from clinic_slots where id = p_id;   -- 신청도 함께 지워져요(on delete cascade)
  return null;
end $$;

create or replace function teacher_clinic_list(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(to_jsonb(b) order by b.created_at) from clinic_bookings b), '[]'::jsonb);
end $$;

create or replace function teacher_clinic_booking_delete(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  delete from clinic_bookings where id = p_id;
  return null;
end $$;

-- 학생 지정: 정원과 상관없이 넣어요. 이미 자율 신청이 있으면 지정으로 바꿔요
create or replace function teacher_clinic_assign(p_token text, p_slot_id text, p_student_ids jsonb, p_reason text)
returns text language plpgsql security definer set search_path = public as $$
declare sid text;
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  if not exists (select 1 from clinic_slots where id = p_slot_id) then return '닫힌 클리닉이에요.'; end if;
  for sid in select jsonb_array_elements_text(p_student_ids) loop
    insert into clinic_bookings(id, slot_id, student_id, kind, reason)
    values ('cb_' || replace(gen_random_uuid()::text, '-', ''), p_slot_id, sid, 'assigned', nullif(p_reason, ''))
    on conflict (slot_id, student_id) do update set kind = 'assigned', reason = excluded.reason,
      confirmed_at = null, decline_reason = null;
  end loop;
  return null;
end $$;

-- ---------- 학생 ----------
-- 돌려주는 값: {"counts": {시간대: 신청 수}, "mine": [내 신청]}  (다른 학생 이름은 안 보여요)
create or replace function student_clinic_list(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u users;
begin
  u := app_session_user(p_token);
  if u.id is null then return '{}'::jsonb; end if;
  return jsonb_build_object(
    'counts', coalesce((select jsonb_object_agg(slot_id, n) from (select slot_id, count(*) n from clinic_bookings group by slot_id) c), '{}'::jsonb),
    'mine', coalesce((select jsonb_agg(to_jsonb(b)) from clinic_bookings b where b.student_id = u.id), '[]'::jsonb));
end $$;

-- 신청. 돌려주는 값: null=성공, 아니면 이유
create or replace function student_clinic_book(p_token text, p_slot_id text, p_memo text)
returns text language plpgsql security definer set search_path = public as $$
declare u users; s clinic_slots;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  select * into s from clinic_slots where id = p_slot_id for update;   -- 동시에 눌러도 정원을 넘지 않게
  if not found then return '닫힌 클리닉이에요.'; end if;
  if not cert_target_ok(s.targets, u.school) then return '우리 학교 클리닉이 아니에요.'; end if;
  if clinic_started(s) then return '이미 시작했거나 지난 시간이에요.'; end if;
  if exists (select 1 from clinic_bookings where slot_id = s.id and student_id = u.id) then return '이미 신청했어요.'; end if;
  if exists (select 1 from clinic_bookings b join clinic_slots x on x.id = b.slot_id
             where b.student_id = u.id and x.date = s.date and b.kind = 'assigned') then
    return '이날은 쏠T가 지정한 클리닉이 있어요.';
  end if;
  if exists (select 1 from clinic_bookings b join clinic_slots x on x.id = b.slot_id
             where b.student_id = u.id and x.date = s.date) then
    return '같은 날 다른 시간에 이미 신청했어요. 먼저 취소해 주세요.';
  end if;
  if s.capacity is not null and (select count(*) from clinic_bookings where slot_id = s.id) >= s.capacity then
    return '자리가 다 찼어요.';
  end if;
  insert into clinic_bookings(id, slot_id, student_id, memo)
  values ('cb_' || replace(gen_random_uuid()::text, '-', ''), s.id, u.id, left(coalesce(p_memo, ''), 200));
  return null;
end $$;

-- 취소 (시작 전까지만)
create or replace function student_clinic_cancel(p_token text, p_slot_id text)
returns text language plpgsql security definer set search_path = public as $$
declare u users; s clinic_slots;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  select * into s from clinic_slots where id = p_slot_id;
  if found and clinic_started(s) then return '이미 시작한 클리닉은 취소할 수 없어요. 쏠T에게 말해 주세요.'; end if;
  if exists (select 1 from clinic_bookings where slot_id = p_slot_id and student_id = u.id and kind = 'assigned') then
    return '쏠T가 지정한 클리닉은 취소할 수 없어요. 못 오면 사유를 적어 주세요.';
  end if;
  delete from clinic_bookings where slot_id = p_slot_id and student_id = u.id and kind = 'self';
  if not found then return '신청한 기록이 없어요.'; end if;
  return null;
end $$;

-- 지정된 학생의 답: p_ok=true '확인했어요' / false 못 오는 사유
create or replace function student_clinic_respond(p_token text, p_slot_id text, p_ok boolean, p_reason text)
returns text language plpgsql security definer set search_path = public as $$
declare u users;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  if not p_ok and coalesce(trim(p_reason), '') = '' then return '못 오는 사유를 적어 주세요.'; end if;
  update clinic_bookings set confirmed_at = case when p_ok then now() else null end,
    decline_reason = case when p_ok then null else left(trim(p_reason), 200) end
  where slot_id = p_slot_id and student_id = u.id and kind = 'assigned';
  if not found then return '지정된 클리닉이 없어요.'; end if;
  return null;
end $$;

grant execute on function teacher_clinic_slot_save(text, jsonb), teacher_clinic_slot_delete(text, text),
  teacher_clinic_list(text), teacher_clinic_booking_delete(text, text), teacher_clinic_assign(text, text, jsonb, text),
  student_clinic_list(text), student_clinic_book(text, text, text), student_clinic_cancel(text, text),
  student_clinic_respond(text, text, boolean, text)
  to anon, authenticated;
