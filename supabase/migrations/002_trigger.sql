-- 002_trigger.sql — 청크 insert 시 윈도우 특징량(RMS/peak) 계산 + 위험 판정 뷰

create or replace function compute_window_features()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into window_features (session_id, chunk_index, ts, lat, lng, n, rms, peak)
  select
    new.session_id,
    new.chunk_index,
    new.start_ts,
    new.lat,
    new.lng,
    new.n_samples,
    sqrt(avg(pow((s->>1)::float, 2) + pow((s->>2)::float, 2) + pow((s->>3)::float, 2))),
    max(sqrt(pow((s->>1)::float, 2) + pow((s->>2)::float, 2) + pow((s->>3)::float, 2)))
  from jsonb_array_elements(new.samples) as s
  on conflict (session_id, chunk_index) do nothing;
  return new;
end;
$$;

create trigger trg_chunk_features
  after insert on sensor_chunks
  for each row execute function compute_window_features();

-- 임계값 초과 윈도우만 심각도와 함께 노출 (대시보드가 읽는 뷰)
create view hazard_windows
with (security_invoker = on) as
select
  w.session_id, w.chunk_index, w.ts, w.lat, w.lng, w.rms, w.peak,
  s.mode,
  case
    when w.rms >= c.danger_rms or w.peak >= c.impact_peak then 'danger'
    else 'warn'
  end as severity
from window_features w
join sessions s on s.id = w.session_id
join detection_config c on c.mode = s.mode
where w.rms >= c.warn_rms or w.peak >= c.impact_peak;
