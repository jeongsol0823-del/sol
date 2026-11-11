-- 클리닉 서버 함수 시험 (앱 방, 2026-11-11)
-- SQL Editor에 전체 붙여넣고 Run. ★ 아무것도 남지 않아요 ★
-- 마지막에 일부러 오류(RAISE EXCEPTION)를 내서, 시험 중 만든 로그인 기록·클리닉 시간·신청이 전부 자동 취소돼요.
-- 화면에 빨간 오류처럼 "TEST ..." 메시지가 뜨면 정상이에요. 그 메시지가 시험 결과예요.
do $$
declare
  t text := 'zz_t_' || md5(random()::text);
  s1 text := 'zz_s1_' || md5(random()::text);
  s2 text := 'zz_s2_' || md5(random()::text);
  u1 text; u2 text; d date := ((now() at time zone 'Asia/Seoul')::date + 1);
  r text; j jsonb; out text := '';
  ok int := 0; bad int := 0;
begin
  select id into u1 from users where role = 'student' and status = 'active' order by id limit 1;
  select id into u2 from users where role = 'student' and status = 'active' and id <> u1 order by id limit 1;
  insert into app_sessions(token, user_id, role) values
    (t, (select id from users where role = 'teacher' and status = 'active' order by id limit 1), 'teacher'),
    (s1, u1, 'student'), (s2, u2, 'student');

  -- 1 강사가 내일 17:00 정원 1명 시간 열기
  r := teacher_clinic_slot_save(t, jsonb_build_object('id','zz_slot','date',d::text,'start_time','17:00','end_time','18:00','capacity','1'));
  if r is null then ok := ok + 1; else bad := bad + 1; out := out || ' [1 열기 실패:' || r || ']'; end if;
  -- 2 학생1 자율 신청
  r := student_clinic_book(s1, 'zz_slot', '시험 신청');
  if r is null then ok := ok + 1; else bad := bad + 1; out := out || ' [2 신청 실패:' || r || ']'; end if;
  -- 3 학생2 자율 신청 → 정원 1명이라 막혀야 함
  r := student_clinic_book(s2, 'zz_slot', '시험');
  if r = '자리가 다 찼어요.' then ok := ok + 1; else bad := bad + 1; out := out || ' [3 정원 막기 안 됨:' || coalesce(r,'성공해 버림') || ']'; end if;
  -- 4 강사가 학생2 지정 (정원과 상관없이 들어가야 함)
  r := teacher_clinic_assign(t, 'zz_slot', jsonb_build_array(u2), '시험 지정');
  if r is null then ok := ok + 1; else bad := bad + 1; out := out || ' [4 지정 실패:' || r || ']'; end if;
  -- 5 지정된 학생2는 취소 못 함
  r := student_clinic_cancel(s2, 'zz_slot');
  if r like '쏠T가 지정한%' then ok := ok + 1; else bad := bad + 1; out := out || ' [5 지정 취소 막기 안 됨:' || coalesce(r,'취소돼 버림') || ']'; end if;
  -- 6 사유 없이 '못 와요' → 막힘, 사유 적으면 됨
  r := student_clinic_respond(s2, 'zz_slot', false, '');
  if r = '못 오는 사유를 적어 주세요.' then ok := ok + 1; else bad := bad + 1; out := out || ' [6a:' || coalesce(r,'null') || ']'; end if;
  r := student_clinic_respond(s2, 'zz_slot', false, '시험 사유');
  if r is null then ok := ok + 1; else bad := bad + 1; out := out || ' [6b:' || r || ']'; end if;
  -- 7 학생1 목록: 자리 수 2, 내 신청 1개, 다른 학생 이름 없음
  j := student_clinic_list(s1);
  if (j->'counts'->>'zz_slot')::int = 2 and jsonb_array_length(j->'mine') = 1 then ok := ok + 1; else bad := bad + 1; out := out || ' [7 학생 목록:' || j::text || ']'; end if;
  -- 8 강사 목록: 2명, 지정 1·자율 1, 못 옴 사유 보임
  j := teacher_clinic_list(t);
  if (select count(*) from jsonb_array_elements(j) e where e->>'slot_id' = 'zz_slot') = 2
     and exists (select 1 from jsonb_array_elements(j) e where e->>'slot_id' = 'zz_slot' and e->>'kind' = 'assigned' and e->>'decline_reason' = '시험 사유')
  then ok := ok + 1; else bad := bad + 1; out := out || ' [8 강사 목록 이상]'; end if;
  -- 9 학생1 자율 취소
  r := student_clinic_cancel(s1, 'zz_slot');
  if r is null then ok := ok + 1; else bad := bad + 1; out := out || ' [9 취소 실패:' || r || ']'; end if;
  -- 10 강사가 시간 닫기 → 신청도 같이 지워짐
  r := teacher_clinic_slot_delete(t, 'zz_slot');
  if r is null and not exists (select 1 from clinic_signups where slot_id = 'zz_slot') then ok := ok + 1; else bad := bad + 1; out := out || ' [10 닫기 이상]'; end if;
  -- 11 가짜 토큰은 막힘
  r := student_clinic_book('가짜', 'zz_slot', 'x');
  if r = 'forbidden' then ok := ok + 1; else bad := bad + 1; out := out || ' [11 가짜 토큰 통과!]'; end if;

  raise exception 'TEST 통과 %/12 · 실패 % % (이 메시지는 시험을 되돌리려고 일부러 낸 오류예요. 남은 데이터 없음)', ok, bad, out;
end $$;
