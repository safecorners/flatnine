-- seed_demo.sql — 파이프라인 E2E 검증용 합성 세션 1개 (인하대 인근 60초 휠체어 주행 시뮬레이션)
-- 청크 20~24: 거친 노면(rms≈0.35), 40~41: 단차 충격(rms≈0.55 + peak 3.0), 나머지: 매끄러움(rms≈0.15)
-- 제거: delete from sessions where id = '00000000-0000-4000-8000-000000000001';

insert into sessions (id, started_at, ended_at, mode, device_model, platform, sample_rate_hz, chunk_count)
values (
  '00000000-0000-4000-8000-000000000001',
  now() - interval '60 seconds', now(),
  'wheelchair', 'Synthetic Seed', 'seed', 100, 60
)
on conflict (id) do nothing;

insert into sensor_chunks (session_id, chunk_index, start_ts, n_samples, samples, lat, lng, gps_accuracy_m, speed_mps)
select
  '00000000-0000-4000-8000-000000000001',
  p.i,
  now() - interval '60 seconds' + make_interval(secs => p.i),
  100,
  s.samples,
  p.lat, p.lng, 4.0, 1.2
from (
  select
    i,
    37.4504 + i * 0.000030 as lat,   -- 북동쪽으로 초당 ~3.5m 이동
    126.6538 + i * 0.000012 as lng,
    case
      when i between 20 and 24 then 0.35
      when i in (40, 41) then 0.55
      else 0.15
    end as amp,
    (i in (40, 41)) as has_impact
  from generate_series(0, 59) as i
) p
cross join lateral (
  select jsonb_agg(
    jsonb_build_array(
      n * 10,
      round(((random() * 2 - 1) * p.amp)::numeric
            + case when p.has_impact and n = 50 then 3.0 else 0 end, 3),
      round(((random() * 2 - 1) * p.amp)::numeric, 3),
      round(((random() * 2 - 1) * p.amp)::numeric, 3),
      round(((random() * 2 - 1) * 0.1)::numeric, 3),
      round(((random() * 2 - 1) * 0.1)::numeric, 3),
      round(((random() * 2 - 1) * 0.1)::numeric, 3)
    ) order by n
  ) as samples
  from generate_series(0, 99) as n
) s
on conflict (session_id, chunk_index) do nothing;
