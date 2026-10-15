-- ============================================================
-- 정말 쏠쏠한 국어 — 어휘 테스트 기능용 테이블 (schema_add3)
-- SQL Editor에 전체 붙여넣고 실행하세요. 기존 테이블/데이터는 건드리지 않습니다.
-- ============================================================

create table if not exists vocab_sets (
  id         text primary key,          -- 'vs_'+Date.now()
  name       text not null,             -- 예: '3주차 어휘'
  created_at timestamptz default now()
);

create table if not exists vocab_words (
  id         text primary key,          -- 'vw_'+Date.now()+랜덤
  set_id     text not null,
  word       text not null,
  meaning    text not null,
  example    text,                      -- 예문 (선택)
  created_at timestamptz default now()
);

create table if not exists vocab_attempts (
  id           text primary key,        -- 'va_'+Date.now()
  set_id       text not null,
  student_id   text not null,
  score        integer default 0,
  total        integer default 0,
  wrong_words  jsonb,                   -- [{word,meaning,example,picked}]
  submitted_at timestamptz default now()
);

alter table vocab_sets    enable row level security;
alter table vocab_words   enable row level security;
alter table vocab_attempts enable row level security;

drop policy if exists "public full access" on vocab_sets;
create policy "public full access" on vocab_sets for all using (true) with check (true);
drop policy if exists "public full access" on vocab_words;
create policy "public full access" on vocab_words for all using (true) with check (true);
drop policy if exists "public full access" on vocab_attempts;
create policy "public full access" on vocab_attempts for all using (true) with check (true);
