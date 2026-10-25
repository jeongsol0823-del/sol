-- ============================================================
-- 정말 쏠쏠한 국어 — 통과한 인증 사진 24시간 뒤 정리 (schema_add20)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================

-- 통과/미통과를 누른 시각 (통과 24시간 뒤 사진 파일을 지울 때 기준)
alter table cert_submissions add column if not exists reviewed_at timestamptz;
-- 이미 통과한 제출은 지금부터 24시간 뒤에 정리돼요
update cert_submissions set reviewed_at = now() where status = 'approved' and reviewed_at is null;

create or replace function teacher_cert_status(p_token text, p_id text, p_status text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  if p_status not in ('approved', 'rejected', 'pending') then return '잘못된 상태예요.'; end if;
  update cert_submissions set status = p_status, reviewed_at = now() where id = p_id;
  return null;
end $$;

-- 사진 파일을 지운 뒤 기록에서 사진 주소를 비워요 (통과 후 24시간 지난 것만)
create or replace function teacher_cert_photos_cleared(p_token text, p_ids text[])
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  update cert_submissions set photo_url = null
   where id = any(p_ids) and status = 'approved' and reviewed_at < now() - interval '24 hours';
  return null;
end $$;

grant execute on function teacher_cert_status(text, text, text), teacher_cert_photos_cleared(text, text[]) to anon, authenticated;
