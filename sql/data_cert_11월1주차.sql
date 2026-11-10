-- 11월 1주차 숙제 인증 등록 (앱 방, 2026-11-10, 쏠T 요청)
-- Supabase SQL 편집기에 전체를 붙여넣고 Run.
-- 10월 5주차와 같은 형식: 주차 이름 "{학교} 11월 1주차", 과제 종류 사진·영상(photo), 대상 그 학교 하나.
-- 마감(due_date)은 표지 제출일 = 그날 자정까지(앱이 다음 날 0시 10분까지 봐줌).
-- 같은 이름의 주차·같은 제목의 과제가 이미 있으면 다시 넣지 않아요(두 번 실행해도 안전).
-- 숙제 PDF는 앱에 올리지 않아요(form_link 비움).

insert into cert_weeks (id, name)
select v.id, v.name from (values
  ('cw_20261110_hyeonam',  '현암고 11월 1주차'),
  ('cw_20261110_punggdeok','풍덕고 11월 1주차'),
  ('cw_20261110_hongcheon','홍천고 11월 1주차'),
  ('cw_20261110_suji',     '수지고 11월 1주차')
) as v(id, name)
where not exists (select 1 from cert_weeks w where w.name = v.name);

insert into cert_items (id, week_id, title, type, targets, due_date)
select v.id, w.id, v.title, 'photo', v.targets, v.due::date
from (values
  ('ci_20261110_hyeonam',   '현암고 11월 1주차', '만언사&봉산탈춤', '["현암고"]', '2026-11-12'),
  ('ci_20261110_punggdeok', '풍덕고 11월 1주차', '누항사',          '["풍덕고"]', '2026-11-13'),
  ('ci_20261110_hongcheon', '홍천고 11월 1주차', '규원가',          '["홍천고"]', '2026-11-13'),
  ('ci_20261110_suji1',     '수지고 11월 1주차', '수오재기',        '["수지고"]', '2026-11-14'),
  ('ci_20261110_suji2',     '수지고 11월 1주차', '중세 국어',       '["수지고"]', '2026-11-14')
) as v(id, week_name, title, targets, due)
join cert_weeks w on w.name = v.week_name
where not exists (select 1 from cert_items i where i.week_id = w.id and i.title = v.title);

-- 확인: 5줄이 나와야 해요
select w.name as 주차, i.title as 과제, i.type as 종류, i.targets as 대상, i.due_date as 마감
from cert_items i join cert_weeks w on w.id = i.week_id
where w.name like '%11월 1주차'
order by w.name, i.title;
