-- 007 — 익명 INSERT 위생 제약
--
-- MVP는 인증이 없어 anon INSERT가 열려 있다(README "보안 경계" 참고).
-- 익명 쓰기 자체는 막을 수 없지만, 최소한 말이 안 되는 값이 들어와
-- 위험 지도를 오염시키거나 용량을 급격히 먹는 일은 줄인다.
--
-- 현재 데이터 범위(2026-08-19): n_samples 47~100, chunk_index 0~247,
-- lat 37.45~37.53, lng 126.65~126.73 — 아래 제약은 모두 이를 통과한다.

alter table sensor_chunks
  add constraint sensor_chunks_n_samples_sane
    check (n_samples between 1 and 500),
  add constraint sensor_chunks_samples_sane
    check (case when jsonb_typeof(samples) = 'array'
                then jsonb_array_length(samples) between 1 and 500
                else false end),
  add constraint sensor_chunks_chunk_index_sane
    check (chunk_index >= 0),
  add constraint sensor_chunks_latlng_sane
    check ((lat is null or lat between -90 and 90)
       and (lng is null or lng between -180 and 180));

alter table sessions
  add constraint sessions_chunk_count_sane
    check (chunk_count between 0 and 100000),
  add constraint sessions_time_order
    check (ended_at >= started_at);
