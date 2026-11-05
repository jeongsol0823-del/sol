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

-- ------------------------------------------------------------
-- 갈래 목록(exam_types)에 2개 추가 (숙제 방 요청, 11-06). 여러 번 실행해도 한 번만 들어가요.
--   '문법 · 맞춤법 · 그 밖의 것 (제51~57항)' → '띄어쓰기' 바로 뒤
--   '문법 · 국어사 · 단어의 의미 변화'       → '근대 국어의 특징' 바로 뒤
-- ------------------------------------------------------------
do $$
declare v jsonb; outv jsonb := '[]'::jsonb; e text;
  a text := '문법 · 맞춤법 · 그 밖의 것 (제51~57항)';
  b text := '문법 · 국어사 · 단어의 의미 변화';
begin
  select value into v from app_settings where key = 'exam_types';
  if v is null then return; end if;   -- 목록을 저장한 적이 없으면 앱 기본 목록을 써요
  for e in select x from jsonb_array_elements_text(v) with ordinality t(x, i) order by i loop
    if e in (a, b) then continue; end if;
    outv := outv || to_jsonb(e);
    if e = '문법 · 맞춤법 · 띄어쓰기' then outv := outv || to_jsonb(a); end if;
    if e = '문법 · 국어사 · 근대 국어의 특징' then outv := outv || to_jsonb(b); end if;
  end loop;
  if not outv ? a then outv := outv || to_jsonb(a); end if;
  if not outv ? b then outv := outv || to_jsonb(b); end if;
  update app_settings set value = outv, updated_at = now() where key = 'exam_types';
end $$;
select jsonb_array_length(value) as "갈래 수 (51이면 정상)" from app_settings where key = 'exam_types';
