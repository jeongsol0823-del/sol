-- 어휘 명예의 전당: 1~3등 학교와 학생 이름 (id는 rank1 / rank2 / rank3)
create table if not exists vocab_hall (
  id text primary key,
  rank integer not null,
  school text,
  name text,
  updated_at timestamptz default now()
);
alter table vocab_hall enable row level security;
drop policy if exists "public full access" on vocab_hall;
create policy "public full access" on vocab_hall for all using (true) with check (true);
