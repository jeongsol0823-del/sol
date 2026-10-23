-- 인증 과제: 대상 학교 고르기 + 제출 보안
-- 제출 기록은 사이트에서 직접 읽거나 쓸 수 없고 서버 함수로만 (학생은 자기 것만, 통과/미통과는 강사만)
-- 과제·주차 목록은 학생 화면에 보여야 해서 읽기는 그대로, 추가·수정·삭제는 강사 함수로만

revoke all on cert_submissions from anon, authenticated;
revoke insert, update, delete on cert_items, cert_weeks from anon, authenticated;

-- 대상 학교: targets가 비어 있으면 전체, 아니면 ["수지고","풍덕고"]
create or replace function cert_target_ok(p_targets text, p_school text)
returns boolean language sql immutable as $$
  select p_targets is null or p_targets in ('', 'null', '[]') or p_targets::jsonb ? coalesce(p_school, '');
$$;

create or replace function student_cert_list(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u users;
begin
  u := app_session_user(p_token);
  if u.id is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(to_jsonb(s)) from cert_submissions s where s.student_id = u.id), '[]'::jsonb);
end $$;

-- 학생 제출 (재제출이면 예전 미통과 기록은 지워요). 돌려주는 값: null=성공, 아니면 이유
create or replace function student_cert_submit(p_token text, p_item_id text, p_photo_url text)
returns text language plpgsql security definer set search_path = public as $$
declare u users; it cert_items;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  select * into it from cert_items where id = p_item_id;
  if not found then return '없는 과제예요.'; end if;
  if not cert_target_ok(it.targets, u.school) then return '우리 학교 과제가 아니에요.'; end if;
  if exists (select 1 from cert_submissions where item_id = p_item_id and student_id = u.id and status <> 'rejected') then
    return '이미 제출했어요.';
  end if;
  if it.type = 'photo' and coalesce(p_photo_url, '') = '' then return '사진을 올려 주세요.'; end if;
  delete from cert_submissions where item_id = p_item_id and student_id = u.id and status = 'rejected';
  insert into cert_submissions(id, item_id, student_id, status, photo_url, submitted_at)
  values ('cs_' || replace(gen_random_uuid()::text, '-', ''), p_item_id, u.id, 'pending', nullif(p_photo_url, ''), now());
  return null;
end $$;

create or replace function teacher_cert_list(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(to_jsonb(s)) from cert_submissions s), '[]'::jsonb);
end $$;

create or replace function teacher_cert_status(p_token text, p_id text, p_status text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  if p_status not in ('approved', 'rejected', 'pending') then return '잘못된 상태예요.'; end if;
  update cert_submissions set status = p_status where id = p_id;
  return null;
end $$;

create or replace function teacher_cert_week_add(p_token text, p_row jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  insert into cert_weeks(id, name) values (p_row->>'id', p_row->>'name');
  return null;
end $$;

-- 과제 추가·수정 (같은 id면 수정)
create or replace function teacher_cert_item_save(p_token text, p_row jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  insert into cert_items(id, week_id, title, type, targets, due_date)
  values (p_row->>'id', p_row->>'week_id', p_row->>'title', coalesce(p_row->>'type', 'check'),
          nullif(p_row->>'targets', ''), nullif(p_row->>'due_date', '')::date)
  on conflict (id) do update set week_id = excluded.week_id, title = excluded.title, type = excluded.type,
    targets = excluded.targets, due_date = excluded.due_date;
  return null;
end $$;

create or replace function teacher_cert_item_delete(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  delete from cert_submissions where item_id = p_id;
  delete from cert_items where id = p_id;
  return null;
end $$;

-- 학생을 지우면 질문과 과제 제출도 같이
create or replace function teacher_user_delete(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  delete from qa_questions where student_id = p_id;
  delete from cert_submissions where student_id = p_id;
  delete from users where id = p_id and role = 'student';
  return null;
end $$;

grant execute on function student_cert_list(text), student_cert_submit(text, text, text), teacher_cert_list(text),
  teacher_cert_status(text, text, text), teacher_cert_week_add(text, jsonb), teacher_cert_item_save(text, jsonb),
  teacher_cert_item_delete(text, text) to anon, authenticated;

-- 인증 사진: 누구나 전체 목록을 불러오는 것을 막아요 (주소로 보기는 그대로)
drop policy if exists "cert-photos read" on storage.objects;
