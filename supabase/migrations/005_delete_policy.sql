-- 005 — 대시보드 세션 삭제 기능용 anon DELETE 정책
-- sensor_chunks·window_features는 FK on delete cascade로 함께 삭제됨
-- (참조 무결성 트리거는 자식 테이블 RLS를 우회하므로 sessions 정책 하나면 충분)
create policy sessions_anon_delete on sessions
  for delete to anon using (true);
