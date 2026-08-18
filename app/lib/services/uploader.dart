import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/recorded_session.dart';
import 'session_store.dart';

/// 세션 업로드: sessions 1행 upsert → sensor_chunks 배치 upsert.
/// remoteId(클라이언트 생성 UUID) + (session_id, chunk_index) unique 제약 +
/// ignoreDuplicates 덕분에 재시도가 멱등이다.
class UploadService {
  UploadService(this._store);

  final SessionStore _store;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> upload(
    RecordedSession session, {
    void Function(int done, int total)? onProgress,
  }) async {
    session.uploadState = 'uploading';
    session.uploadedChunks = 0;
    await _store.saveMeta(session);

    try {
      final chunks = await _store.readChunks(session.localId);

      // 실제 저장된 청크 수를 선언값으로 사용 (크래시로 일부만 남았을 수 있음)
      session.chunkCount = chunks.length;
      await _client.from('sessions').upsert(
            session.toRow(),
            onConflict: 'id',
            ignoreDuplicates: true,
          );

      for (var i = 0; i < chunks.length; i += uploadBatchSize) {
        final batch = chunks.sublist(
          i,
          i + uploadBatchSize > chunks.length
              ? chunks.length
              : i + uploadBatchSize,
        );
        await _client.from('sensor_chunks').upsert(
              [for (final c in batch) c.toRow(session.remoteId)],
              onConflict: 'session_id,chunk_index',
              ignoreDuplicates: true,
            );
        session.uploadedChunks += batch.length;
        onProgress?.call(session.uploadedChunks, chunks.length);
        await _store.saveMeta(session);
      }

      session.uploadState = 'uploaded';
      await _store.saveMeta(session);
    } catch (e) {
      session.uploadState = 'failed';
      await _store.saveMeta(session);
      rethrow;
    }
  }
}
