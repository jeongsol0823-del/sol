-- ============================================================
-- 정말 쏠쏠한 국어 — 학부모용 성적표 PDF (schema_add8)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================

-- 만든 PDF 목록
create table if not exists report_links (
  id         text primary key,
  student_id text not null,
  url        text not null,   -- 학부모님께 보내는 링크
  path       text not null,   -- 저장소 안 파일 위치
  note       text,            -- 쏠T 선생님 한마디
  created_at timestamptz default now()
);
alter table report_links enable row level security;
drop policy if exists "public full access" on report_links;
create policy "public full access" on report_links for all using (true) with check (true);

-- PDF 저장 공간 (reports)
insert into storage.buckets (id, name, public)
values ('reports', 'reports', true)
on conflict (id) do update set public = true;

drop policy if exists "reports read" on storage.objects;
create policy "reports read" on storage.objects for select using (bucket_id = 'reports');
drop policy if exists "reports upload" on storage.objects;
create policy "reports upload" on storage.objects for insert with check (bucket_id = 'reports');

-- 사진·PDF 삭제 허용 (학생 삭제, PDF 삭제할 때)
drop policy if exists "photos delete" on storage.objects;
create policy "photos delete" on storage.objects
  for delete using (bucket_id in ('qa-photos', 'cert-photos', 'reports'));
