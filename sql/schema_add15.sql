-- 질문답변: 방(학교/반·주차) 없이 바로 질문 + 학생은 자기 질문만 볼 수 있게
-- 질문 표는 사이트에서 직접 읽거나 쓸 수 없고, 아래 서버 함수로만 주고받아요 (로그인 토큰 확인)

alter table qa_questions add column if not exists source text;                     -- 교재 / 시험지 이름
alter table qa_questions add column if not exists created_at timestamptz default now();

revoke all on qa_questions from anon, authenticated;

-- 토큰 → 로그인한 사용자 (서버 함수 안에서만 써요)
create or replace function app_session_user(p_token text)
returns users language sql stable security definer set search_path = public as $$
  select u.* from app_sessions s join users u on u.id = s.user_id
   where s.token = p_token and u.status = 'active' and s.last_seen > now() - interval '90 days';
$$;
revoke execute on function app_session_user(text) from public, anon, authenticated;

-- 학생: 내 질문만
create or replace function student_qa_list(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u users;
begin
  u := app_session_user(p_token);
  if u.id is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from qa_questions q where q.student_id = u.id), '[]'::jsonb);
end $$;

-- 학생: 질문 올리기 (학교·이름은 계정에서 자동으로)
create or replace function student_qa_submit(p_token text, p_row jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare u users; qid text;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  qid := coalesce(nullif(p_row->>'id', ''), 'q_' || replace(gen_random_uuid()::text, '-', ''));
  if coalesce(btrim(p_row->>'question'), '') = '' then return '질문 내용을 입력하세요.'; end if;
  insert into qa_questions(id, school_id, week_id, prob_num, student_id, student_name, question, status, badge,
                           photo_url, teacher_reply, category, source, created_at)
  values (qid, u.school, 'q_' || qid, left(coalesce(p_row->>'prob_num', ''), 20), u.id, u.name,
          left(p_row->>'question', 2000), 'pending', 'pending', nullif(p_row->>'photo_url', ''), null,
          nullif(p_row->>'category', ''), left(nullif(p_row->>'source', ''), 100), now());
  return null;
end $$;

-- 강사: 전체 질문
create or replace function teacher_qa_list(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from qa_questions q), '[]'::jsonb);
end $$;

create or replace function teacher_qa_answer(p_token text, p_id text, p_reply text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  update qa_questions set teacher_reply = p_reply, status = 'answered', badge = 'teacher' where id = p_id;
  return null;
end $$;

create or replace function teacher_qa_delete(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  delete from qa_questions where id = p_id;
  return null;
end $$;

-- 학생 이름을 바꾸면 질문에 적힌 이름도 같이, 학생을 지우면 질문도 같이
create or replace function teacher_user_update(p_token text, p_id text, p_patch jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  update users set
    name       = case when p_patch ? 'name'       then p_patch->>'name' else name end,
    school     = case when p_patch ? 'school'     then nullif(p_patch->>'school', '') else school end,
    grade      = case when p_patch ? 'grade'      then (p_patch->>'grade')::int else grade end,
    grade_year = case when p_patch ? 'grade_year' then (p_patch->>'grade_year')::int else grade_year end,
    status     = case when p_patch ? 'status'     then p_patch->>'status' else status end,
    pw         = case when p_patch ? 'pw'         then p_patch->>'pw' else pw end
  where id = p_id and role = 'student';
  if p_patch ? 'name' then update qa_questions set student_name = p_patch->>'name' where student_id = p_id; end if;
  if p_patch ? 'school' then update qa_questions set school_id = nullif(p_patch->>'school', '') where student_id = p_id; end if;
  if p_patch ? 'pw' or (p_patch ? 'status' and p_patch->>'status' <> 'active') then
    delete from app_sessions where user_id = p_id;
  end if;
  return null;
end $$;

create or replace function teacher_user_delete(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  delete from qa_questions where student_id = p_id;
  delete from users where id = p_id and role = 'student';
  return null;
end $$;

grant execute on function student_qa_list(text), student_qa_submit(text, jsonb), teacher_qa_list(text),
  teacher_qa_answer(text, text, text), teacher_qa_delete(text, text) to anon, authenticated;

-- 질문 사진: 목록 보기(누구나 전체 파일 목록을 불러오기)를 막아요.
-- 사진 주소를 아는 사람(질문한 학생 본인과 쏠T 화면)만 볼 수 있어요. 공개 저장소라 주소로 보기는 그대로 돼요.
drop policy if exists "qa-photos read" on storage.objects;
