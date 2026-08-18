-- 004 — 트리거 전용 함수는 REST RPC로 호출될 필요가 없다 (security advisor 경고 해소)
revoke execute on function public.compute_window_features() from public, anon, authenticated;
