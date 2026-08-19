-- 006 — 세션 삭제를 소유자 토큰 기반 RPC로 제한
--
-- 배경: 005의 sessions_anon_delete는 using(true)였다. anon(publishable) 키는
-- 앱 바이너리와 대시보드 JS 번들에 그대로 실려 나가는 공개 값이므로, 이 정책은
-- "키를 본 누구나 전체 세션을 지울 수 있다"는 뜻이었다. FK cascade 때문에
-- sensor_chunks·window_features까지 함께 사라지고 무료 티어에는 PITR이 없다.
--
-- 대안: 앱이 세션마다 토큰을 만들어 기기에만 보관하고, 서버에는 SHA-256 해시만
-- 저장한다. 삭제는 토큰을 아는 호출자만 가능하다. 해시는 anon SELECT로 읽혀도
-- 원본 토큰을 복원할 수 없으므로 대시보드의 select(*)를 깨지 않는다.

-- 참고: Supabase security advisor는 "anon이 실행 가능한 SECURITY DEFINER 함수"
-- 경고(0028)를 띄운다. 이는 의도된 설계다 — 삭제하려면 RLS를 우회해야 하고,
-- 앱은 로그인 없이 호출해야 한다. 대신 122비트 랜덤 토큰 일치를 요구하고
-- search_path를 고정해 함수 자체의 공격면을 닫았다.

alter table sessions add column if not exists owner_token_hash text;

drop policy if exists sessions_anon_delete on sessions;

create or replace function public.delete_session(p_id uuid, p_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  -- 빈 토큰으로 owner_token_hash is null 인 행을 건드리지 못하게 방어
  if p_token is null or length(p_token) < 16 then
    return false;
  end if;

  delete from sessions
  where id = p_id
    and owner_token_hash is not null
    and owner_token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex');

  get diagnostics n = row_count;
  return n > 0;
end;
$$;

revoke all on function public.delete_session(uuid, text) from public, anon, authenticated;
grant execute on function public.delete_session(uuid, text) to anon;
