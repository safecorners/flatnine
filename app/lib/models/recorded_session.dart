import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 측정 세션 메타데이터. 로컬 `sessions/<localId>/meta.json`에 저장되고
/// 업로드 시 서버 `sessions` 1행이 된다.
class RecordedSession {
  final String localId;

  /// 업로드 멱등성을 위해 측정 시작 시 클라이언트에서 생성하는 UUID.
  /// 재시도해도 같은 id로 upsert되어 중복 세션이 생기지 않는다.
  final String remoteId;

  /// 서버 삭제 권한 증명용 토큰. 기기 밖으로 나가지 않고, 서버에는 SHA-256
  /// 해시만 올라간다 (anon 키만 가진 제3자가 남의 세션을 못 지우게 하는 장치).
  /// 이 필드가 생기기 전에 만들어진 세션은 null.
  final String? ownerToken;

  final String mode; // walk | wheelchair | stroller
  final DateTime startedAt;
  DateTime? endedAt;
  int chunkCount;
  double? sampleRateHz;
  String? deviceModel;
  String platform;
  String uploadState; // local | uploading | uploaded | failed
  int uploadedChunks;

  RecordedSession({
    required this.localId,
    required this.remoteId,
    this.ownerToken,
    required this.mode,
    required this.startedAt,
    this.endedAt,
    this.chunkCount = 0,
    this.sampleRateHz,
    this.deviceModel,
    this.platform = 'android',
    this.uploadState = 'local',
    this.uploadedChunks = 0,
  });

  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'remote_id': remoteId,
        'owner_token': ownerToken,
        'mode': mode,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt?.toUtc().toIso8601String(),
        'chunk_count': chunkCount,
        'sample_rate_hz': sampleRateHz,
        'device_model': deviceModel,
        'platform': platform,
        'upload_state': uploadState,
        'uploaded_chunks': uploadedChunks,
      };

  factory RecordedSession.fromJson(Map<String, dynamic> json) =>
      RecordedSession(
        localId: json['local_id'] as String,
        remoteId: json['remote_id'] as String,
        ownerToken: json['owner_token'] as String?,
        mode: json['mode'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.parse(json['ended_at'] as String),
        chunkCount: json['chunk_count'] as int? ?? 0,
        sampleRateHz: (json['sample_rate_hz'] as num?)?.toDouble(),
        deviceModel: json['device_model'] as String?,
        platform: json['platform'] as String? ?? 'android',
        uploadState: json['upload_state'] as String? ?? 'local',
        uploadedChunks: json['uploaded_chunks'] as int? ?? 0,
      );

  /// Supabase `sessions` insert 행.
  /// 토큰 자체가 아니라 해시만 올린다 — 서버가 읽혀도 삭제 권한이 새지 않는다.
  Map<String, dynamic> toRow() => {
        'id': remoteId,
        'owner_token_hash':
            ownerToken == null ? null : sha256OwnerToken(ownerToken!),
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': (endedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'mode': mode,
        'device_model': deviceModel,
        'platform': platform,
        'sample_rate_hz': sampleRateHz,
        'chunk_count': chunkCount,
      };
}

/// 소유자 토큰 해시 — 서버 `sessions.owner_token_hash`와 같은 정의
/// (006 마이그레이션의 `encode(sha256(convert_to(token,'UTF8')),'hex')`).
String sha256OwnerToken(String token) =>
    sha256.convert(utf8.encode(token)).toString();

/// 외부 패키지 없이 쓰는 UUID v4 생성기.
String uuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final s = b.map((i) => i.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
      '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}
