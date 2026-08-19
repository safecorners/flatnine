import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/recorded_session.dart';
import '../services/session_store.dart';
import '../services/uploader.dart';
import '../widgets/track_map.dart';
import '../widgets/upload_area.dart';
import 'record_screen.dart' show modeLabels;

/// 측정 종료 후 페이지: 전체 경로 지도(S→F) + 세션 요약 + 업로드.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.session,
    required this.track,
    required this.distanceM,
  });

  final RecordedSession session;
  final List<Position> track;
  final double distanceM;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _store = SessionStore();
  late final _uploader = UploadService(_store);
  bool _uploading = false;

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      await _uploader.upload(widget.session,
          onProgress: (_, __) => mounted ? setState(() {}) : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('업로드 완료 (청크 ${widget.session.chunkCount}개)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('업로드 실패: $e'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final d = s.duration;
    final durationText =
        '${d.inMinutes}분 ${(d.inSeconds % 60).toString().padLeft(2, '0')}초';
    final started = s.startedAt.toLocal();
    final startedText = '${started.month}/${started.day} '
        '${started.hour.toString().padLeft(2, '0')}:'
        '${started.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('측정 완료')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TrackMapView(
                  points: [
                    for (final p in widget.track)
                      LatLng(p.latitude, p.longitude)
                  ],
                  fitAll: true,
                  overlayHint: '기록된 GPS 경로가 없습니다',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _Stat(label: '모드', value: modeLabels[s.mode] ?? s.mode),
                    _Stat(label: '시작', value: startedText),
                    _Stat(label: '경과 시간', value: durationText),
                    _Stat(
                        label: '이동 거리',
                        value: formatDistance(widget.distanceM)),
                    _Stat(label: '청크', value: '${s.chunkCount}'),
                    _Stat(
                        label: '평균 Hz',
                        value: s.sampleRateHz?.toStringAsFixed(0) ?? '—'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            UploadArea(session: s, uploading: _uploading, onUpload: _upload),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('새 측정', style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }

}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
