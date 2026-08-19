import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/recorder.dart';
import '../widgets/track_map.dart';
import 'recording_screen.dart';
import 'session_list_screen.dart';

const modeLabels = {
  'wheelchair': '휠체어',
  'stroller': '유모차',
  'walk': '보행',
};

/// 측정 시작 페이지: 지도(지난 궤적) + 이동 수단 선택 + 측정 시작.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.recorder});

  final RecorderService recorder;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  String _mode = 'wheelchair';

  Future<void> _startRecording() async {
    final recorder = widget.recorder;
    await recorder.start(_mode);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => RecordingScreen(recorder: recorder)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recorder = widget.recorder;
    return Scaffold(
      appBar: AppBar(
        title: const Text('노면 측정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '세션 목록',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionListScreen()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: recorder,
        builder: (context, _) {
          final fix = recorder.lastFix;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TrackMapView(
                      points: [
                        for (final p in recorder.track)
                          LatLng(p.latitude, p.longitude)
                      ],
                      current: fix == null
                          ? null
                          : LatLng(fix.latitude, fix.longitude),
                      overlayHint: '측정을 시작하면\n이동 경로가 표시됩니다',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    for (final entry in modeLabels.entries)
                      ButtonSegment(
                          value: entry.key, label: Text(entry.value)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) =>
                      setState(() => _mode = s.first),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                  onPressed: _startRecording,
                  child: const Text('측정 시작', style: TextStyle(fontSize: 22)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
