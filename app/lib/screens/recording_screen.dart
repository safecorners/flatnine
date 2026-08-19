import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/recorder.dart';
import '../widgets/magnitude_chart.dart';
import '../widgets/track_map.dart';
import 'record_screen.dart' show modeLabels;
import 'summary_screen.dart';

/// 측정 중 페이지: 경로 추적 지도 + 라이브 지표 + 측정 종료.
/// 뒤로가기는 잠겨 있고 측정 종료 버튼으로만 나갈 수 있다.
class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key, required this.recorder});

  final RecorderService recorder;

  Future<void> _stop(BuildContext context) async {
    final track = List.of(recorder.track);
    final distanceM = recorder.distanceM;
    final session = await recorder.stop();
    if (session == null || !context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          session: session,
          track: track,
          distanceM: distanceM,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: ListenableBuilder(
            listenable: recorder,
            builder: (context, _) => Text(
                '측정 중 · ${modeLabels[recorder.current?.mode] ?? ''}'),
          ),
        ),
        body: ListenableBuilder(
          listenable: recorder,
          builder: (context, _) {
            final fix = recorder.lastFix;
            final e = recorder.elapsed;
            final elapsedText =
                '${e.inMinutes}:${(e.inSeconds % 60).toString().padLeft(2, '0')}';
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
                        follow: true,
                        overlayHint: 'GPS 대기 중…',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BigStat(label: '경과 시간', value: elapsedText),
                      _BigStat(
                          label: '이동 거리',
                          value: formatDistance(recorder.distanceM)),
                      _BigStat(
                          label: '|a| m/s²',
                          value:
                              recorder.currentMagnitude.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MagnitudeChart(values: recorder.magnitudeHistory),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _SmallStat(
                          label: '샘플 수', value: '${recorder.totalSamples}'),
                      _SmallStat(
                          label: '실효 Hz',
                          value: recorder.effectiveHz.toStringAsFixed(1)),
                      _SmallStat(label: '청크', value: '${recorder.chunkCount}'),
                      _SmallStat(
                        label: 'GPS',
                        value: recorder.gpsError ??
                            (fix == null
                                ? '대기 중…'
                                : '±${fix.accuracy.toStringAsFixed(0)}m'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _stop(context),
                    child:
                        const Text('측정 종료', style: TextStyle(fontSize: 22)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

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
