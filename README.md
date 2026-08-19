# flatnine - 보행 약자 노면 위험 감지 MVP

> 구 RoadSense에서 flatnine으로 리브랜딩 (2026-08).

스마트폰 IMU(가속도·자이로 ~100Hz) + GPS로 휠체어·유모차·보행 이용자가 겪는
노면 진동을 측정하고, 포트홀·단차 같은 위험 지점을 지도로 시각화하는 서비스.

> 2026 AI·디지털 기반 문제해결·창작 프로젝트 — 8/29 성과발표회 출품작.
> 타당성 조사는 [RESEARCH.md](RESEARCH.md) 참고.

## 데이터 파이프라인

```
Flutter 앱 (Android)              Supabase (Postgres)               Next.js 대시보드 (Vercel)
─────────────────────            ──────────────────────            ─────────────────────────
userAccelerometer ~100Hz    →    sensor_chunks (1초 JSONB 행)   →   지도(react-leaflet + OSM)
+ gyro ~100Hz + GPS 1Hz          → INSERT trigger가 즉시             RMS 심각도 색상 트랙
1초 청크로 묶어 배치 업로드        window_features(RMS/peak) 생성      위험 마커 + RMS 타임라인
                                 → hazard_windows 뷰(임계값 판정)
```

- 이상 감지는 서버(Postgres trigger)에서 1초 윈도우 RMS/피크로 수행.
- 임계값은 `detection_config` 테이블에서 mode별로 UPDATE 한 줄로 캘리브레이션.

## 구성

| 디렉토리 | 내용 |
|---|---|
| `app/` | Flutter 측정 앱 (Android). 측정 화면 + 세션 목록/업로드 화면 |
| `dashboard/` | Next.js 대시보드. 전체 위험 지도(`/`) + 세션 상세(`/session/[id]`) |
| `supabase/migrations/` | 스키마·트리거·RLS SQL (Supabase에 적용된 사본) |

## 실행

### 앱 (Android)

```bash
cd app
flutter pub get
flutter run
```

- Supabase 연결 정보는 `app/lib/config.dart`에 채운다 (URL + publishable key).
- 값이 비어 있으면 로컬 기록만 되고 업로드 버튼이 비활성화된다.

### 대시보드

```bash
cd dashboard
npm install
npm run dev
```

- `.env.local`에 `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` 설정.

## 측정 팁

- 폰은 유모차·핸드카트 등 바퀴 달린 장치에 **고정 거치**를 권장 (연구 임계값과 정합).
- 방향은 무관 (중력 제거된 선형가속도의 크기 |a| 사용).
- 실내에서는 GPS가 잡히지 않으므로 야외에서 측정.
