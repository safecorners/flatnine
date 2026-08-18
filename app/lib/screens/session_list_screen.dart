import 'package:flutter/material.dart';

import '../config.dart';
import '../models/recorded_session.dart';
import '../services/session_store.dart';
import '../services/uploader.dart';
import 'record_screen.dart' show modeLabels;

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final _store = SessionStore();
  late final _uploader = UploadService(_store);

  List<RecordedSession> _sessions = [];
  final Set<String> _uploading = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final sessions = await _store.list();
    if (mounted) setState(() => _sessions = sessions);
  }

  Future<void> _upload(RecordedSession session) async {
    setState(() => _uploading.add(session.localId));
    try {
      await _uploader.upload(session,
          onProgress: (_, __) => mounted ? setState(() {}) : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('업로드 완료 (청크 ${session.chunkCount}개)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('업로드 실패: $e'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _uploading.remove(session.localId));
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('세션 목록')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _sessions.isEmpty
            ? ListView(children: const [
                Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: Text('아직 측정한 세션이 없습니다')),
                ),
              ])
            : ListView.builder(
                itemCount: _sessions.length,
                itemBuilder: (context, i) =>
                    _sessionCard(context, _sessions[i]),
              ),
      ),
    );
  }

  Widget _sessionCard(BuildContext context, RecordedSession s) {
    final uploading = _uploading.contains(s.localId);
    final d = s.duration;
    final durationText =
        '${d.inMinutes}분 ${(d.inSeconds % 60).toString().padLeft(2, '0')}초';
    final started = s.startedAt.toLocal();
    final dateText = '${started.month}/${started.day} '
        '${started.hour.toString().padLeft(2, '0')}:'
        '${started.minute.toString().padLeft(2, '0')}';

    final (stateLabel, stateColor) = switch (s.uploadState) {
      'uploaded' => ('업로드 완료', Colors.green),
      'uploading' => ('업로드 중', Colors.orange),
      'failed' => ('실패', Colors.red),
      _ => ('로컬', Colors.grey),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text('$dateText · ${modeLabels[s.mode] ?? s.mode}'),
        subtitle: Text(
          '$durationText · 청크 ${s.chunkCount}개'
          '${s.sampleRateHz != null ? ' · ${s.sampleRateHz!.toStringAsFixed(0)}Hz' : ''}'
          '${uploading ? ' · ${s.uploadedChunks}/${s.chunkCount} 업로드 중' : ''}',
        ),
        leading: CircleAvatar(
          backgroundColor: stateColor.withValues(alpha: 0.15),
          child: Icon(
            switch (s.uploadState) {
              'uploaded' => Icons.cloud_done,
              'failed' => Icons.error_outline,
              _ => Icons.smartphone,
            },
            color: stateColor,
          ),
        ),
        trailing: uploading
            ? const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator())
            : s.uploadState == 'uploaded'
                ? Text(stateLabel, style: TextStyle(color: stateColor))
                : FilledButton.tonal(
                    onPressed: supabaseConfigured ? () => _upload(s) : null,
                    child: Text(s.uploadState == 'failed' ? '재시도' : '업로드'),
                  ),
        onLongPress: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('세션 삭제'),
              content: Text('$dateText 세션을 삭제할까요? (기기에서만 삭제됩니다)'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('삭제')),
              ],
            ),
          );
          if (confirmed == true) {
            await _store.delete(s.localId);
            await _refresh();
          }
        },
      ),
    );
  }
}
