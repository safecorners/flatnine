import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/recorded_session.dart';
import '../services/session_store.dart';
import '../services/uploader.dart';
import '../widgets/track_map.dart';
import '../widgets/upload_area.dart';
import 'record_screen.dart' show modeLabels;

/// 세션 상세 페이지: 저장된 청크의 GPS 스냅샷으로 경로를 복원해 보여주고,
/// 업로드/삭제를 제공한다. 삭제 시 pop(true)로 목록 새로고침을 알린다.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.session});

  final RecordedSession session;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _store = SessionStore();
  late final _uploader = UploadService(_store);
  bool _uploading = false;

  List<LatLng>? _points; // null = 로딩 중
  double _distanceM = 0;

  @override
  void initState() {
    super.initState();
    _loadTrack();
  }

  /// 청크의 1초 단위 GPS 스냅샷으로 경로 복원 (recorder와 같은 2m 필터)
  Future<void> _loadTrack() async {
    final chunks = await _store.readChunks(widget.session.localId);
    final pts = <LatLng>[];
    double dist = 0;
    for (final c in chunks) {
      final lat = c.lat, lng = c.lng;
      if (lat == null || lng == null) continue;
      if (pts.isNotEmpty) {
        final d = Geolocator.distanceBetween(
            pts.last.latitude, pts.last.longitude, lat, lng);
        if (d < 2) continue;
        dist += d;
      }
      pts.add(LatLng(lat, lng));
    }
    if (mounted) {
      setState(() {
        _points = pts;
        _distanceM = dist;
      });
    }
  }

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

  Future<void> _delete() async {
    final s = widget.session;
    // 업로드 이력이 있으면 서버 데이터도 함께 삭제
    final removeRemote = supabaseConfigured &&
        (s.uploadState == 'uploaded' || s.uploadedChunks > 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('세션 삭제'),
        content: Text(removeRemote
            ? '이 세션을 삭제할까요?\n기기와 서버(Supabase)에서 모두 삭제됩니다.'
            : '이 세션을 삭제할까요?\n(기기에서만 삭제됩니다)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제',
                style:
                    TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (removeRemote) {
      try {
        await _uploader.deleteRemote(s);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('서버 삭제 실패: $e'),
              backgroundColor: Theme.of(context).colorScheme.error));
        }
        return; // 서버 삭제 실패 시 로컬도 유지 (재시도 가능하게)
      }
    }
    await _store.delete(s.localId);
    if (mounted) Navigator.of(context).pop(true);
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
    final points = _points;

    return Scaffold(
      appBar: AppBar(
        title: Text('$startedText · ${modeLabels[s.mode] ?? s.mode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '세션 삭제',
            onPressed: _uploading ? null : _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: points == null
                    ? const Center(child: CircularProgressIndicator())
                    : TrackMapView(
                        points: points,
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
                    _Stat(label: '경과 시간', value: durationText),
                    _Stat(
                        label: '이동 거리',
                        value: points == null
                            ? '…'
                            : formatDistance(_distanceM)),
                    _Stat(label: '청크', value: '${s.chunkCount}'),
                    _Stat(
                        label: '평균 Hz',
                        value: s.sampleRateHz?.toStringAsFixed(0) ?? '—'),
                    if (s.deviceModel != null)
                      _Stat(label: '기기', value: s.deviceModel!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            UploadArea(
              session: s,
              uploading: _uploading,
              onUpload: _upload,
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
