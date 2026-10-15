-- ============================================================
-- 정말 쏠쏠한 국어 — 2단계 추가 기능용 테이블
-- (출석체크 / 공지사항 / 인증 사진업로드에 필요해요)
-- SQL Editor에 전체 붙여넣고 실행하세요. 기존 테이블/데이터는 건드리지 않습니다.
-- ============================================================

-- 출석체크
create table if not exists attendance (
  id         text primary key,          -- 'att_'+Date.now()
  student_id text not null,
  date       text not null,             -- 'YYYY-MM-DD'
  status     text not null default 'present', -- 'present' | 'late' | 'absent'
  note       text,
  created_at timestamptz default now(),
  unique (student_id, date)             -- 하루 한 건, upsert로 덮어쓰기
);

-- 공지사항
create table if not exists announcements (
  id         text primary key,          -- 'an_'+Date.now()
  title      text not null,
  content    text,
  created_at timestamptz default now()
);

create table if not exists announcement_reads (
  id              text primary key,     -- 'ar_'+Date.now()
  announcement_id text not null,
  student_id      text not null,
  read_at         timestamptz default now(),
  unique (announcement_id, student_id)
);

alter table attendance         enable row level security;
alter table announcements      enable row level security;
alter table announcement_reads enable row level security;

drop policy if exists "public full access" on attendance;
create policy "public full access" on attendance for all using (true) with check (true);
drop policy if exists "public full access" on announcements;
create policy "public full access" on announcements for all using (true) with check (true);
drop policy if exists "public full access" on announcement_reads;
create policy "public full access" on announcement_reads for all using (true) with check (true);

-- ============================================================
-- 인증 과제 사진 업로드용 Storage 버킷
-- SQL로는 만들 수 없어요 — Supabase 대시보드에서 딱 한 번만 해주시면 돼요:
--   1) 왼쪽 메뉴 Storage → "New bucket"
--   2) 이름: cert-photos   (정확히 이 이름으로!)
--   3) "Public bucket" 체크 → Create
-- 이렇게 만들어두시면 인증 과제 사진 업로드 기능이 바로 동작해요.
-- ============================================================
