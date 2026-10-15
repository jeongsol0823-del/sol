-- ============================================================
-- 정말 쏠쏠한 국어 — 1단계(핵심 기능) Supabase 스키마
-- Supabase 대시보드 → SQL Editor 에 전체 붙여넣고 실행하세요.
-- 이미 만든 테이블이 있어도 안전하게 실행되도록 IF NOT EXISTS로 작성했습니다.
-- ============================================================

-- 1) 사용자 (학생/강사)
create table if not exists public.users (
  id text primary key,                                  -- 로그인 아이디
  name text not null,
  pw text not null,                                      -- 비밀번호 (원본 사이트와 동일하게 평문 저장 — 아래 보안 안내 참고)
  role text not null check (role in ('student','teacher')),
  status text not null default 'pending' check (status in ('pending','active')),
  school_id text,
  created_at timestamptz not null default now()
);

-- 2) 강의 영상
create table if not exists public.videos (
  id text primary key,
  title text not null,
  url text not null,
  description text default '',
  category text not null default 'lecture',              -- lecture(일반 강의) — 추후 review/clinic 등 추가 예정
  created_at timestamptz not null default now()
);

-- 3) 학생별 시청 진도
create table if not exists public.progress (
  student_id text not null references public.users(id) on delete cascade,
  video_id text not null references public.videos(id) on delete cascade,
  percent numeric not null default 0,
  watch_seconds numeric not null default 0,
  last_position numeric not null default 0,
  max_rate numeric not null default 1,
  updated_at timestamptz not null default now(),
  primary key (student_id, video_id)
);

-- Row Level Security 활성화
alter table public.users enable row level security;
alter table public.videos enable row level security;
alter table public.progress enable row level security;

-- 이 앱은 Supabase Auth를 쓰지 않고, 로그인 아이디/비밀번호를 앱 코드에서 직접 대조합니다
-- (원본 사이트와 동일한 방식). 그래서 anon 키에 테이블 접근 권한을 열어줘야 앱이 동작합니다.
-- ⚠️ 보안 참고: anon 키는 웹페이지 소스에 그대로 노출되는 "공개" 키이기 때문에,
-- 이 정책 하에서는 누구든 anon 키만 있으면 users 테이블의 비밀번호(pw)까지 읽을 수 있습니다.
-- 원본 사이트도 동일한 구조였지만, 실제 운영 전에는 비밀번호 해시 처리 + Supabase Auth 전환을
-- 권장드립니다. 지금 단계는 "기능 우선"으로 빠르게 만드는 것이 목표라 원본과 동일하게 갑니다.

drop policy if exists "anon full access users" on public.users;
create policy "anon full access users" on public.users for all to anon using (true) with check (true);

drop policy if exists "anon full access videos" on public.videos;
create policy "anon full access videos" on public.videos for all to anon using (true) with check (true);

drop policy if exists "anon full access progress" on public.progress;
create policy "anon full access progress" on public.progress for all to anon using (true) with check (true);

-- 쏠T 강사 계정 최초 시딩 (이미 있으면 건드리지 않음)
-- 로그인 아이디: solt / 비밀번호: change-me-1234  → 첫 로그인 후 반드시 비밀번호를 바꿔주세요.
insert into public.users (id, name, pw, role, status)
values ('solt', '쏠T', 'change-me-1234', 'teacher', 'active')
on conflict (id) do nothing;
