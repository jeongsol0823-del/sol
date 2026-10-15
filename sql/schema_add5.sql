-- ============================================================
-- 정말 쏠쏠한 국어 — 질문 사진 / 영상 배속·건너뛰기 기록 (schema_add5)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================

-- 질문답변: 문제 사진 주소
alter table qa_questions add column if not exists photo_url text;

-- 영상 진도: 실제로 본 구간, 영상 길이, 배속별 시청 시간
alter table progress add column if not exists watched_ranges jsonb;  -- [[시작초, 끝초], ...]
alter table progress add column if not exists duration       integer; -- 영상 길이(초)
alter table progress add column if not exists rate_seconds   jsonb;  -- {"1": 300, "1.5": 120, "2": 60}

-- 질문 사진 저장 공간 (qa-photos)
insert into storage.buckets (id, name, public)
values ('qa-photos', 'qa-photos', true)
on conflict (id) do update set public = true;

drop policy if exists "qa-photos read" on storage.objects;
create policy "qa-photos read" on storage.objects
  for select using (bucket_id = 'qa-photos');
drop policy if exists "qa-photos upload" on storage.objects;
create policy "qa-photos upload" on storage.objects
  for insert with check (bucket_id = 'qa-photos');

-- 학생을 삭제할 때 그 학생이 올린 사진도 같이 지울 수 있게
drop policy if exists "photos delete" on storage.objects;
create policy "photos delete" on storage.objects
  for delete using (bucket_id in ('qa-photos', 'cert-photos'));
