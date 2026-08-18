/// Supabase 연결 정보 — 프로젝트 생성 후 실제 값으로 채운다.
/// 값이 비어 있으면 앱은 로컬 기록만 하고 업로드 버튼이 비활성화된다.
const String supabaseUrl = 'https://dhmfdtomxofqymgroopg.supabase.co';
const String supabasePublishableKey =
    'sb_publishable_bDGiG3VGsY98PBa1sU_T0g__cFkcLbA';

bool get supabaseConfigured =>
    supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

/// 1초 청크(= 서버 탐지 윈도우) 길이
const int chunkMillis = 1000;

/// 업로드 배치 크기 (행 수) — 약 1분 30초 분량, 요청당 ~250KB
const int uploadBatchSize = 30;
