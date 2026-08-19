import 'package:flutter/material.dart';

import '../config.dart';
import '../models/recorded_session.dart';

/// 세션 업로드 상태 표시 + 업로드 버튼 (요약/상세 페이지 공용).
/// 상태별로 완료(초록) / 진행률 바 / 업로드·재시도 버튼을 보여준다.
class UploadArea extends StatelessWidget {
  const UploadArea({
    super.key,
    required this.session,
    required this.uploading,
    required this.onUpload,
  });

  final RecordedSession session;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    if (!supabaseConfigured) return const SizedBox.shrink();

    final s = session;
    if (s.uploadState == 'uploaded') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done, color: Colors.green),
          const SizedBox(width: 8),
          Text('업로드 완료 (청크 ${s.chunkCount}개)',
              style: const TextStyle(color: Colors.green)),
        ],
      );
    }

    if (uploading) {
      final progress =
          s.chunkCount > 0 ? s.uploadedChunks / s.chunkCount : null;
      return Column(
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('업로드 중… ${s.uploadedChunks}/${s.chunkCount}'),
        ],
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
      onPressed: onUpload,
      icon: const Icon(Icons.cloud_upload),
      label: Text(s.uploadState == 'failed' ? '업로드 재시도' : '업로드'),
    );
  }
}
