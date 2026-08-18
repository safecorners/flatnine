import 'package:flutter/material.dart';

import '../services/recorder.dart';
import 'session_list_screen.dart';

const modeLabels = {
  'wheelchair': '휠체어',
  'stroller': '유모차',
  'walk': '보행',
};

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.recorder});

  final RecorderService recorder;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  String _mode = 'wheelchair';

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
          final recording = recorder.state == RecorderState.recording;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: [
                    for (final entry in modeLabels.entries)
                      ButtonSegment(
                          value: entry.key, label: Text(entry.value)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: recording
                      ? null
                      : (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          recorder.currentMagnitude.toStringAsFixed(2),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Text('|a| m/s² (선형가속도 크기)'),
                        const SizedBox(height: 24),
                        _StatsGrid(recorder: recorder),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    backgroundColor: recording
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  onPressed: () async {
                    if (recording) {
                      final session = await recorder.stop();
                      if (context.mounted && session != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '측정 종료 — 청크 ${session.chunkCount}개 저장됨. '
                              '세션 목록에서 업로드하세요.'),
                        ));
                      }
                    } else {
                      await recorder.start(_mode);
                    }
                  },
                  child: Text(
                    recording ? '측정 종료' : '측정 시작',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.recorder});

  final RecorderService recorder;

  @override
  Widget build(BuildContext context) {
    final fix = recorder.lastFix;
    final recording = recorder.state == RecorderState.recording;
    final gpsText = recorder.gpsError ??
        (fix == null
            ? (recording ? '대기 중…' : '—')
            : '±${fix.accuracy.toStringAsFixed(0)}m');
    final e = recorder.elapsed;
    final elapsedText = recording
        ? '${e.inMinutes}:${(e.inSeconds % 60).toString().padLeft(2, '0')}'
        : '—';

    Widget stat(String label, String value) => Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        );

    return Wrap(
      spacing: 32,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        stat('경과 시간', elapsedText),
        stat('샘플 수', '${recorder.totalSamples}'),
        stat('실효 Hz',
            recording ? recorder.effectiveHz.toStringAsFixed(1) : '—'),
        stat('청크', '${recorder.chunkCount}'),
        stat('GPS', gpsText),
      ],
    );
  }
}
