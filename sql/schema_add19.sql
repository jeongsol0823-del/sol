-- ============================================================
-- 정말 쏠쏠한 국어 — 영상 시청 중 다른 화면으로 나간 기록 (schema_add19)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================

alter table progress add column if not exists away_count   integer default 0;  -- 재생 중 다른 화면(앱·탭·창)으로 나간 횟수
alter table progress add column if not exists away_seconds integer default 0;  -- 나가 있던 시간(초)
