import 'dart:math';

import 'package:flutter/material.dart';

/// |a| 파형 차트.
/// live=true(측정 중): 최신 값이 오른쪽 끝에 붙어 왼쪽으로 흐르는 60초 스트립.
/// live=false(요약·상세): 세션 전체 시리즈를 플롯 폭에 맞춰 정적으로 표시.
/// 단일 시리즈 — 테마 primary 라인(2px) + 은은한 면 채움, Y축 자동 스케일.
class MagnitudeChart extends StatelessWidget {
  const MagnitudeChart(
      {super.key, required this.values, this.height = 90, this.live = true});

  /// live: 200ms 버킷 peak(RecorderService.magnitudeHistory),
  /// 정적: 청크(1초)별 peak(chunkPeakSeries)
  final List<double> values;
  final double height;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size.infinite,
        painter: _MagnitudePainter(
          values: List.of(values),
          live: live,
          lineColor: scheme.primary,
          fillColor: scheme.primary.withValues(alpha: 0.12),
          gridColor: scheme.outlineVariant.withValues(alpha: 0.5),
          labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
        ),
      ),
    );
  }
}

/// 세션 전체 진동 파형 섹션 (캡션 + 정적 차트) — 요약·상세 페이지 공용.
/// peaks가 null이면 로딩 중(빈 그리드 표시).
class PeakChartSection extends StatelessWidget {
  const PeakChartSection({super.key, required this.peaks});

  final List<double>? peaks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text('진동 강도 |a| · 1초 peak',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        MagnitudeChart(values: peaks ?? const [], height: 80, live: false),
      ],
    );
  }
}

class _MagnitudePainter extends CustomPainter {
  _MagnitudePainter({
    required this.values,
    required this.live,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<double> values;
  final bool live;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final TextStyle labelStyle;

  /// Y축 최소 상한 (m/s²) — 평지 보행 수준에서도 파형이 보이게
  static const _minCeiling = 5.0;
  static const _maxPoints = 300;
  static const _pad = EdgeInsets.only(left: 4, right: 4, top: 12, bottom: 4);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_pad.left, _pad.top, size.width - _pad.right,
        size.height - _pad.bottom);

    final maxVal = values.isEmpty ? 0.0 : values.reduce(max);
    final ceiling = max(_minCeiling, maxVal * 1.1);

    double yOf(double v) =>
        plot.bottom - (v / ceiling).clamp(0.0, 1.0) * plot.height;

    // 그리드: 중간선 + 베이스라인 (은은하게)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final midY = yOf(ceiling / 2);
    canvas.drawLine(Offset(plot.left, midY), Offset(plot.right, midY), gridPaint);
    canvas.drawLine(Offset(plot.left, plot.bottom),
        Offset(plot.right, plot.bottom), gridPaint);

    // 상한·중간 눈금 라벨 (좌측, 값은 텍스트 토큰 색)
    _label(canvas, ceiling.toStringAsFixed(0), Offset(plot.left + 2, _pad.top - 11));
    _label(canvas, (ceiling / 2).toStringAsFixed(1), Offset(plot.left + 2, midY - 12));

    if (values.length < 2) return;

    // live: 최신 값을 오른쪽 끝에 고정하고 왼쪽으로 스크롤 (고정 60초 창)
    // 정적: 전체 시리즈를 플롯 폭에 맞춤
    final n = values.length;
    final dx = live ? plot.width / (_maxPoints - 1) : plot.width / (n - 1);
    final line = Path();
    final area = Path();
    for (var i = 0; i < n; i++) {
      final x = plot.right - (n - 1 - i) * dx;
      final y = yOf(values[i]);
      if (i == 0) {
        line.moveTo(x, y);
        area.moveTo(x, plot.bottom);
        area.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        area.lineTo(x, y);
      }
    }
    area.lineTo(plot.right, plot.bottom);
    area.close();

    canvas.drawPath(area, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MagnitudePainter old) => true;
}
