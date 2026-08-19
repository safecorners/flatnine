import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 이동 경로 지도 (측정 시작/측정 중/종료 요약 3개 화면 공용).
/// OSM 타일 + 궤적 폴리라인 + 출발(S)/도착(F)/현재 위치 마커.
class TrackMapView extends StatefulWidget {
  const TrackMapView({
    super.key,
    required this.points,
    this.current,
    this.follow = false,
    this.fitAll = false,
    this.overlayHint,
  });

  /// 궤적 (시간순)
  final List<LatLng> points;

  /// 현재 위치 (파란 점). null이면 표시하지 않음.
  final LatLng? current;

  /// true면 카메라가 current를 따라감 (측정 중 화면)
  final bool follow;

  /// true면 첫 화면에서 전체 궤적이 보이게 맞추고 끝점에 F 마커 (종료 요약 화면)
  final bool fitAll;

  /// 표시할 위치 데이터가 없을 때 지도 위에 띄울 안내 문구
  final String? overlayHint;

  @override
  State<TrackMapView> createState() => _TrackMapViewState();
}

class _TrackMapViewState extends State<TrackMapView> {
  final _controller = MapController();
  bool _mapReady = false;

  // fix가 없을 때의 기본 중심 (인천 계양구 인근)
  static const _fallbackCenter = LatLng(37.5323, 126.7293);

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final current = widget.current;

    if (widget.follow && current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) {
          _controller.move(current, _controller.camera.zoom);
        }
      });
    }

    final empty = points.isEmpty && current == null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: current ??
                (points.isNotEmpty ? points.last : _fallbackCenter),
            initialZoom: 17,
            initialCameraFit: widget.fitAll && points.length >= 2
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(48),
                  )
                : null,
            onMapReady: () => _mapReady = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.safecorners.flatnine',
            ),
            if (points.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 5,
                  color: Colors.blueAccent,
                ),
              ]),
            MarkerLayer(markers: [
              if (points.isNotEmpty)
                Marker(
                  point: points.first,
                  width: 24,
                  height: 24,
                  child: const DotMarker(color: Colors.green, label: 'S'),
                ),
              if (widget.fitAll && points.length >= 2)
                Marker(
                  point: points.last,
                  width: 24,
                  height: 24,
                  child: const DotMarker(color: Colors.red, label: 'F'),
                ),
              if (current != null)
                Marker(
                  point: current,
                  width: 20,
                  height: 20,
                  child: const DotMarker(color: Colors.blue),
                ),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
        if (empty && widget.overlayHint != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Text(
                  widget.overlayHint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class DotMarker extends StatelessWidget {
  const DotMarker({super.key, required this.color, this.label});

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
      ),
      child: label == null
          ? null
          : Center(
              child: Text(label!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
    );
  }
}

/// 거리 표시 공용 포맷 (1km 미만은 m, 이상은 km)
String formatDistance(double meters) => meters < 1000
    ? '${meters.toStringAsFixed(0)}m'
    : '${(meters / 1000).toStringAsFixed(2)}km';
