-- ============================================================
-- 정말 쏠쏠한 국어 — 시험 제한시간 + 정답 공개 (schema_add7)
-- SQL Editor에 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- (schema_add6.sql 내용도 포함돼 있어서 이것만 실행하면 돼요)
-- ============================================================
alter table exams add column if not exists time_limit integer;                   -- 분, 비어 있으면 제한 없음
alter table exams add column if not exists answers_revealed boolean default false; -- 정답 공개 여부
