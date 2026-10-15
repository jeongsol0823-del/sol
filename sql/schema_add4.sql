-- ============================================================
-- 정말 쏠쏠한 국어 — 어휘 미션용 칸 추가 (schema_add4)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================

alter table vocab_sets  add column if not exists track        text;     -- 교재 (중학 / 수능 ...)
alter table vocab_sets  add column if not exists lesson_no    integer;  -- 강 번호
alter table vocab_sets  add column if not exists lesson_title text;     -- 강 제목
alter table vocab_sets  add column if not exists open_date    date;     -- 미션 오픈일

alter table vocab_words add column if not exists hanja        text;     -- 한자
alter table vocab_words add column if not exists sort_no      integer;  -- 미션 안 단어 순서
