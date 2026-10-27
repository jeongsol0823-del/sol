-- ============================================================
-- 정말 쏠쏠한 국어 — 사진·영상 주소 검사와 저장소 크기 제한 (schema_add21)
-- SQL Editor에 전체 붙여넣고 Run 하세요. 기존 데이터는 그대로 남아요.
-- ============================================================

-- 학생이 낸 사진·영상 주소는 "우리 저장소의 자기 폴더" 주소만 받아요
-- (다른 사이트 주소나 위험한 링크를 심어 선생님이 누르게 하는 것 막기)
create or replace function media_urls_ok(p_urls text, p_bucket text, p_uid text)
returns boolean language sql immutable as $$
  select coalesce(bool_and(starts_with(u, 'https://munbqhqudknwlanlwqxr.supabase.co/storage/v1/object/public/' || p_bucket || '/' || p_uid || '/')), true)
    from regexp_split_to_table(coalesce(p_urls, ''), '\s+') as u
   where u <> '';
$$;

create or replace function student_cert_submit(p_token text, p_item_id text, p_photo_url text)
returns text language plpgsql security definer set search_path = public as $$
declare u users; it cert_items;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  select * into it from cert_items where id = p_item_id;
  if not found then return '없는 과제예요.'; end if;
  if not cert_target_ok(it.targets, u.school) then return '우리 학교 과제가 아니에요.'; end if;
  if exists (select 1 from cert_submissions where item_id = p_item_id and student_id = u.id and status <> 'rejected') then
    return '이미 제출했어요.';
  end if;
  if it.type = 'photo' and coalesce(p_photo_url, '') = '' then return '사진을 올려 주세요.'; end if;
  if not media_urls_ok(p_photo_url, 'cert-photos', u.id) then return '사진·영상 주소가 올바르지 않아요.'; end if;
  delete from cert_submissions where item_id = p_item_id and student_id = u.id and status = 'rejected';
  insert into cert_submissions(id, item_id, student_id, status, photo_url, submitted_at)
  values ('cs_' || replace(gen_random_uuid()::text, '-', ''), p_item_id, u.id, 'pending', nullif(p_photo_url, ''), now());
  return null;
end $$;

create or replace function student_qa_submit(p_token text, p_row jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare u users; qid text;
begin
  u := app_session_user(p_token);
  if u.id is null or u.role <> 'student' then return 'forbidden'; end if;
  qid := coalesce(nullif(p_row->>'id', ''), 'q_' || replace(gen_random_uuid()::text, '-', ''));
  if coalesce(btrim(p_row->>'question'), '') = '' then return '질문 내용을 입력하세요.'; end if;
  if not media_urls_ok(p_row->>'photo_url', 'qa-photos', u.id) then return '사진 주소가 올바르지 않아요.'; end if;
  insert into qa_questions(id, school_id, week_id, prob_num, student_id, student_name, question, status, badge,
                           photo_url, teacher_reply, category, source, created_at)
  values (qid, u.school, 'q_' || qid, left(coalesce(p_row->>'prob_num', ''), 20), u.id, u.name,
          left(p_row->>'question', 2000), 'pending', 'pending', nullif(p_row->>'photo_url', ''), null,
          nullif(p_row->>'category', ''), left(nullif(p_row->>'source', ''), 100), now());
  return null;
end $$;

grant execute on function student_cert_submit(text, text, text), student_qa_submit(text, jsonb) to anon, authenticated;

-- 저장소: 파일 하나 크기와 종류 제한 (아주 큰 파일이나 엉뚱한 파일로 공간을 채우는 것 막기)
update storage.buckets set file_size_limit = 20 * 1024 * 1024,
       allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif','image/gif','video/mp4','video/webm','video/quicktime']
 where id = 'cert-photos';
update storage.buckets set file_size_limit = 15 * 1024 * 1024,
       allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif','image/gif']
 where id = 'qa-photos';
