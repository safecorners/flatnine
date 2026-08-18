-- 001_schema.sql — roadsense 핵심 스키마
-- 파이프라인: Flutter 앱(1초 청크 업로드) → sensor_chunks → trigger → window_features → hazard_windows 뷰

create table sessions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  started_at timestamptz not null,
  ended_at timestamptz not null,
  mode text not null check (mode in ('walk', 'wheelchair', 'stroller')),
  device_model text,
  platform text,
  sample_rate_hz real,          -- 앱이 측정한 실효 샘플레이트
  chunk_count int not null      -- 앱이 선언; 대시보드가 실제 count(*)와 비교해 업로드 완료 판정
);

create table sensor_chunks (
  id bigint generated always as identity primary key,
  session_id uuid not null references sessions(id) on delete cascade,
  chunk_index int not null,
  start_ts timestamptz not null,
  n_samples int not null,
  samples jsonb not null,       -- [[dt_ms, ax, ay, az, gx, gy, gz], ...] 선형가속도(m/s²) + 자이로(rad/s)
  lat double precision,
  lng double precision,
  gps_accuracy_m real,
  speed_mps real,
  unique (session_id, chunk_index)
);

create table window_features (
  session_id uuid not null references sessions(id) on delete cascade,
  chunk_index int not null,
  ts timestamptz not null,
  lat double precision,
  lng double precision,
  n int not null,
  rms real not null,            -- RMS of |a_linear| (m/s²), 1초 윈도우
  peak real not null,           -- max |a_linear| — 단차/포트홀 순간 충격 지표
  primary key (session_id, chunk_index)
);

-- 임계값은 재배포 없이 UPDATE 한 줄로 캘리브레이션 (연구 초기값; walk는 걸음 진동 베이스라인이 높음)
create table detection_config (
  mode text primary key,
  warn_rms real not null,
  danger_rms real not null,
  impact_peak real not null
);

insert into detection_config (mode, warn_rms, danger_rms, impact_peak) values
  ('wheelchair', 0.30, 0.45, 2.5),
  ('stroller',   0.30, 0.45, 2.5),
  ('walk',       0.80, 1.20, 4.0);

create index idx_sensor_chunks_session on sensor_chunks (session_id, chunk_index);
create index idx_window_features_ts on window_features (ts);
