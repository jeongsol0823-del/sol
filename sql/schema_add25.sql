-- ============================================================
-- 정말 쏠쏠한 국어 — 학생별 시험(받는 학생) + 묶음 (schema_add25)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 시험·응시 기록은 그대로 남아요.
-- ============================================================
-- assignee_id   : 이 시험을 받는 학생(users.id). 비어 있으면 지금처럼 공유코드로 들어가는 시험
-- assignee_name : 올릴 때의 학생 이름(확인용)
-- bundle        : 묶음 이름 (예: "수지고 11월 1주차 복습테스트"). 강사 화면에서 묶어 보여 주고,
--                 정답 공개·제한시간을 묶음 단위로 한 번에 바꿀 때 써요
-- 문항마다 공통/개별 구분(part), 공통 몇 번째(ci), 지난주 몇 번 대신(from), 1:1·2:1(pair), 은행 ID(bank_id)는
-- 기존 questions(jsonb) 안에 들어가서 따로 칸이 필요 없어요.
alter table exams add column if not exists assignee_id   text;
alter table exams add column if not exists assignee_name text;
alter table exams add column if not exists bundle        text;
create index if not exists exams_assignee_idx on exams (assignee_id);
create index if not exists exams_bundle_idx   on exams (bundle);
