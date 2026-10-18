-- 문법 기초 강의: 수강 신청/승인 + 강 번호
create table if not exists grammar_enroll (
  id text primary key,
  student_id text not null,
  status text not null default 'pending',
  created_at timestamptz default now(),
  decided_at timestamptz
);
alter table grammar_enroll enable row level security;
drop policy if exists "public full access" on grammar_enroll;
create policy "public full access" on grammar_enroll for all using (true) with check (true);
alter table videos add column if not exists sort_no integer;
