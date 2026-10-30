-- ============================================================
-- 정말 쏠쏠한 국어 — 학생이 인증 제출을 직접 취소하기 (schema_add24)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================
-- 학생 본인 제출 중 "확인 대기"인 것만 지워요. 통과·미통과로 확인한 제출은 취소할 수 없어요.
-- 돌려주는 값: null=성공, 아니면 이유
create or replace function student_cert_cancel(p_token text, p_item_id text)
returns text language plpgsql security definer set search_path = public as $$
declare u users;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  delete from cert_submissions where item_id = p_item_id and student_id = u.id and status = 'pending';
  if not found then return '쏠T가 이미 확인한 제출은 취소할 수 없어요.'; end if;
  return null;
end $$;
grant execute on function student_cert_cancel(text, text) to anon, authenticated;
