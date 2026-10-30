-- ============================================================
-- 정말 쏠쏠한 국어 — 숙제 영상 3분, 통과하면 파일 바로 지우기 (schema_add23)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 통과 기록은 그대로 남아요.
-- ============================================================
-- 인증 사진·영상 파일 하나의 한도를 20MB에서 50MB로 늘려요. (3분 영상은 20~30MB 정도예요)
update storage.buckets set file_size_limit = 50 * 1024 * 1024
 where id = 'cert-photos';

-- 통과한 제출은 24시간을 기다리지 않고 바로 파일 주소를 비울 수 있게 해요
create or replace function teacher_cert_photos_cleared(p_token text, p_ids text[])
returns text language plpgsql security definer set search_path = public as $$
begin
  if not app_is_teacher(p_token) then return 'forbidden'; end if;
  update cert_submissions set photo_url = null
   where id = any(p_ids) and status = 'approved';
  return null;
end $$;
grant execute on function teacher_cert_photos_cleared(text, text[]) to anon, authenticated;
