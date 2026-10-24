-- ============================================================
-- 정말 쏠쏠한 국어 — 어휘 미션 문제 종류 추가 (schema_add18)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================

-- kind: 비어 있으면 뜻 고르기(기존 방식)
--       'spell' = 바른 표기 고르기 (word = 바른 표기, alt = 틀린 표기, meaning = 설명)
--       'syn'   = 뜻이 통하는 말 고르기 (alt = 유의어 목록, 쉼표로 구분)
--       'ant'   = 반의어 고르기 (alt = 반의어 목록, 쉼표로 구분)
alter table vocab_words add column if not exists kind text;
alter table vocab_words add column if not exists alt  text;
