-- 인증 과제 마감일 (비어 있으면 마감 없음)
alter table cert_items add column if not exists due_date date;
