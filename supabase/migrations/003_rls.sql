-- 003_rls.sql — MVP 정책: 앱(anon)은 insert만, 대시보드(anon)는 읽기만
-- 트레이드오프: anon key로 누구나 insert 가능. 8일 데모에서 수용, 인증·서명은 확장 단계.

alter table sessions enable row level security;
alter table sensor_chunks enable row level security;
alter table window_features enable row level security;
alter table detection_config enable row level security;

-- 앱: 세션/청크 insert
create policy sessions_anon_insert on sessions
  for insert to anon with check (true);
create policy chunks_anon_insert on sensor_chunks
  for insert to anon with check (true);

-- 대시보드: 공개 읽기 (원시 청크는 완료 판정용 count 포함 디버그 겸 허용)
create policy sessions_anon_select on sessions
  for select to anon using (true);
create policy chunks_anon_select on sensor_chunks
  for select to anon using (true);
create policy features_anon_select on window_features
  for select to anon using (true);
create policy config_anon_select on detection_config
  for select to anon using (true);

-- UPDATE/DELETE 정책 없음 — 업로드 완료 판정은 chunk_count 선언값 vs count(*) 비교로 대체
