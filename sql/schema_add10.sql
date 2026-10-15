-- ============================================================
-- 정말 쏠쏠한 국어 — 학교·학년, 영상 수업 구분 (schema_add10)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- (schema_add9 내용도 포함돼 있어요)
-- ============================================================

-- 학생 학교·학년 (grade_year = 그 학년을 입력한 학년도, 3월 1일마다 자동으로 올라감)
alter table users add column if not exists school     text;
alter table users add column if not exists grade      integer;
alter table users add column if not exists grade_year integer;

-- 영상이 어느 수업인지: 날짜 + 학교 + 학년
alter table videos add column if not exists class_date date;
alter table videos add column if not exists school     text;
alter table videos add column if not exists grade      integer;

-- 학교 목록 (학생 가입할 때 고르는 목록)
create table if not exists schools (
  id         text primary key,
  name       text not null unique,
  created_at timestamptz default now()
);
alter table schools enable row level security;
drop policy if exists "public full access" on schools;
create policy "public full access" on schools for all using (true) with check (true);
