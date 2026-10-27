-- ============================================================
-- 정말 쏠쏠한 국어 — 사진·영상 파일 지우기 고치기 (schema_add22)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================
-- 저장소는 파일을 지울 때도 "보기" 권한이 필요해요. 목록 보기를 막아 둔 뒤로 앱의 지우기가 조용히 실패했어요.
-- 앱이 요청에 로그인 토큰(x-sol-token)을 실어 보내면, 강사는 전체, 학생은 자기 폴더만 보고 지울 수 있게 해요.
-- 토큰 없는 사람은 지금처럼 목록을 볼 수 없어요. (사진 주소로 바로 열기는 그대로 돼요)

drop policy if exists "zz probe" on storage.objects;

create or replace function sol_media_access(p_name text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare t text; u users;
begin
  t := nullif(current_setting('request.headers', true)::json->>'x-sol-token', '');
  if t is null then return false; end if;
  if app_is_teacher(t) then return true; end if;
  u := app_session_user(t);
  return u.id is not null and split_part(p_name, '/', 1) = u.id;
end $$;
grant execute on function sol_media_access(text) to anon, authenticated;

drop policy if exists "media select with token" on storage.objects;
create policy "media select with token" on storage.objects
  for select using (bucket_id in ('cert-photos', 'qa-photos') and sol_media_access(name));

-- 지우기도 같은 기준으로 (예전에는 누구나 지우기를 시도할 수 있었어요). 성적표 PDF(reports)는 예전 그대로
drop policy if exists "photos delete" on storage.objects;
drop policy if exists "media delete with token" on storage.objects;
create policy "media delete with token" on storage.objects
  for delete using (bucket_id in ('cert-photos', 'qa-photos') and sol_media_access(name));
drop policy if exists "reports delete" on storage.objects;
create policy "reports delete" on storage.objects
  for delete using (bucket_id = 'reports');
