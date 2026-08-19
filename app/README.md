# flatnine

보행 약자(휠체어·유모차·보행자)를 위한 노면 위험 감지 측정 앱.

폰의 선형가속도(~100Hz)·자이로·GPS를 1초 청크로 기록하고 Supabase로 업로드한다.
위험 구간 판정은 서버(DB 트리거), 시각화는 `dashboard/`(Next.js)가 담당한다.

## 실행

```bash
flutter pub get
flutter run            # 연결된 기기에서 실행
flutter build apk      # Android 릴리스
flutter build ios      # iOS 릴리스 (서명 필요)
```

Supabase 연결 정보는 `lib/config.dart`에 있다.

## 구조

- `lib/screens/` — 측정 시작 → 측정 중 → 종료 요약 3페이지 흐름 + 세션 목록/상세
- `lib/services/recorder.dart` — 센서 수집·1초 청크 조립·GPS 궤적
- `lib/services/uploader.dart` — 멱등 업로드(배치 upsert)·서버 삭제
- `lib/widgets/` — 경로 지도(OSM), |a| 실시간 파형 차트
