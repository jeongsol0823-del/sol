-- 로그인 보안
-- 1) 비밀번호(pw) 칸은 사이트에서 읽을 수 없게: 로그인은 서버 함수(app_login)가 확인
-- 2) 로그인 상태는 서버가 발급한 무작위 토큰으로만 인정 (브라우저 저장값을 고쳐서 강사로 들어가는 것 차단)
-- 3) 학생 계정 추가·수정·삭제·비밀번호 보기는 강사 토큰이 있어야만 (서버 함수)
-- 4) 같은 아이디로 10분 안에 10번 틀리면 잠시 로그인 막기

create table if not exists app_sessions (
  token text primary key,
  user_id text not null references users(id) on delete cascade,
  role text not null,
  created_at timestamptz default now(),
  last_seen timestamptz default now()
);
alter table app_sessions enable row level security;
revoke all on app_sessions from anon, authenticated;

create table if not exists app_login_fails (
  id bigserial primary key,
  login_id text,
  at timestamptz default now()
);
alter table app_login_fails enable row level security;
revoke all on app_login_fails from anon, authenticated;

-- users: 비밀번호 칸을 뺀 나머지만 읽기 허용, 직접 추가·수정·삭제는 막기
revoke all on users from anon, authenticated;
grant select (id, name, role, status, school_id, created_at, school, grade, grade_year) on users to anon, authenticated;

-- 로그인: 맞으면 토큰과 사용자 정보(비밀번호 빼고)를 돌려줌
create or replace function app_login(p_id text, p_pw text, p_role text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u users; t text;
begin
  if (select count(*) from app_login_fails where login_id = p_id and at > now() - interval '10 minutes') >= 10 then
    return jsonb_build_object('error', 'too_many');
  end if;
  select * into u from users where id = p_id and role = p_role;
  if not found or u.pw is distinct from p_pw then
    insert into app_login_fails(login_id) values (p_id);
    delete from app_login_fails where at < now() - interval '1 day';
    return jsonb_build_object('error', 'bad');
  end if;
  if u.status <> 'active' then return jsonb_build_object('error', 'pending'); end if;
  delete from app_login_fails where login_id = p_id;
  t := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into app_sessions(token, user_id, role) values (t, u.id, u.role);
  delete from app_sessions where last_seen < now() - interval '90 days';
  return jsonb_build_object('token', t, 'user', to_jsonb(u) - 'pw');
end $$;

-- 저장된 토큰으로 로그인 상태 확인
create or replace function app_session(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u users;
begin
  select users.* into u from app_sessions s join users on users.id = s.user_id
   where s.token = p_token and users.status = 'active' and s.last_seen > now() - interval '90 days';
  if not found then return null; end if;
  update app_sessions set last_seen = now() where token = p_token;
  return to_jsonb(u) - 'pw';
end $$;

create or replace function app_logout(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from app_sessions where token = p_token;
$$;

create or replace function app_is_teacher(p_token text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from app_sessions s join users u on u.id = s.user_id
                 where s.token = p_token and u.role = 'teacher' and u.status = 'active');
$$;

-- 강사: 학생 계정 만들기 (돌려주는 값: null=성공, 아니면 오류 이유)
create or replace function teacher_user_create(p_token text, p_row jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  insert into users(id, name, pw, role, status, school, grade, grade_year)
  values (p_row->>'id', p_row->>'name', p_row->>'pw', 'student', 'active',
          nullif(p_row->>'school', ''), (p_row->>'grade')::int, (p_row->>'grade_year')::int);
  return null;
exception when unique_violation then return 'duplicate';
end $$;

-- 강사: 학생 정보 바꾸기 (patch에 들어 있는 칸만: name, school, grade, grade_year, status, pw)
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
  if p_patch ? 'pw' or (p_patch ? 'status' and p_patch->>'status' <> 'active') then
    delete from app_sessions where user_id = p_id; -- 비밀번호를 바꾸면 이미 로그인된 기기는 로그아웃
  end if;
  return null;
end $$;

create or replace function teacher_user_delete(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  delete from users where id = p_id and role = 'student';
  return null;
end $$;

-- 강사: 학생 비밀번호 보기
create or replace function teacher_user_pw(p_token text, p_id text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return null; end if;
  return (select pw from users where id = p_id and role = 'student');
end $$;

revoke execute on function app_is_teacher(text) from public, anon, authenticated;
grant execute on function app_login(text, text, text), app_session(text), app_logout(text),
  teacher_user_create(text, jsonb), teacher_user_update(text, text, jsonb),
  teacher_user_delete(text, text), teacher_user_pw(text, text) to anon, authenticated;
