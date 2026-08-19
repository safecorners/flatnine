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
| `app/` | Flutter 측정 앱 (iOS/Android). 측정 시작→측정 중→요약 3화면 + 세션 목록/상세 |
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

## 보안 경계

`app/lib/config.dart`와 대시보드 `.env.local`에 들어가는 **publishable(anon) 키는
비밀이 아니다.** 설계상 클라이언트에 배포되는 값이고, 앱 바이너리와 브라우저 번들에서
누구나 읽을 수 있다. 실제 접근 통제는 전부 Postgres RLS가 담당한다.

| 대상 | anon 권한 | 근거 |
|---|---|---|
| `sessions`, `sensor_chunks` | INSERT | 앱 업로드 (인증 없는 MVP) |
| `sessions`, `sensor_chunks`, `window_features`, `detection_config` | SELECT | 공개 위험 지도 |
| `sessions` DELETE | **불가** | 소유자 토큰을 아는 호출자만 `delete_session()` RPC로 삭제 |

세션 삭제는 앱이 세션마다 만드는 토큰으로만 가능하다. 토큰은 기기에만 남고 서버에는
SHA-256 해시만 저장되므로([006](supabase/migrations/006_delete_by_owner_token.sql)),
키를 가진 제3자가 남의 측정 데이터를 지울 수 없다.

**알려진 한계 (MVP):** 익명 INSERT가 열려 있어 위조 데이터 주입을 막지 못한다.
사용자 인증과 업로드 서명은 확장 단계 과제다.

## 측정 팁

- 폰은 유모차·핸드카트 등 바퀴 달린 장치에 **고정 거치**를 권장 (연구 임계값과 정합).
- 방향은 무관 (중력 제거된 선형가속도의 크기 |a| 사용).
- 실내에서는 GPS가 잡히지 않으므로 야외에서 측정.
