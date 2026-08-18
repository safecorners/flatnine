import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config.dart';
import '../models/recorded_session.dart';
import '../models/sensor_chunk.dart';
import 'session_store.dart';

enum RecorderState { idle, recording }

/// 측정의 심장부.
/// userAccelerometer(선형가속도) ~100Hz를 주 스트림으로 삼고,
/// 최근 gyro 값을 각 accel 이벤트에 페어링해 1초 청크로 조립한다.
/// 청크는 즉시 로컬 JSONL에 append(크래시 대비)되고 GPS 스냅샷이 붙는다.
class RecorderService extends ChangeNotifier {
  RecorderService(this._store);

  final SessionStore _store;

  RecorderState state = RecorderState.idle;
  RecordedSession? current;

  // 라이브 표시용
  double currentMagnitude = 0;
  int totalSamples = 0;
  double effectiveHz = 0;
  int chunkCount = 0;
  Position? lastFix;
  String? gpsError;
  Duration get elapsed => current == null
      ? Duration.zero
      : DateTime.now().difference(current!.startedAt);

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<Position>? _posSub;
  Timer? _uiTimer;

  List<List<num>> _buffer = [];
  DateTime? _chunkEventStart; // 이벤트 타임스탬프 기준 청크 시작
  DateTime? _chunkWallStart; // 벽시계 기준 청크 시작 (서버 start_ts용)
  double _gx = 0, _gy = 0, _gz = 0;

  static const _samplingPeriod = Duration(milliseconds: 10); // 100Hz 힌트

  Future<void> start(String mode) async {
    if (state == RecorderState.recording) return;

    final deviceModel = await _deviceModel();
    final now = DateTime.now();
    current = RecordedSession(
      localId: now.millisecondsSinceEpoch.toString(),
      remoteId: uuidV4(),
      mode: mode,
      startedAt: now,
      deviceModel: deviceModel,
      platform: Platform.isAndroid ? 'android' : Platform.operatingSystem,
    );
    await _store.saveMeta(current!);

    totalSamples = 0;
    chunkCount = 0;
    effectiveHz = 0;
    currentMagnitude = 0;
    lastFix = null;
    gpsError = null;
    _buffer = [];
    _chunkEventStart = null;
    _chunkWallStart = null;

    await WakelockPlus.enable();
    await _startGps();

    _gyroSub = gyroscopeEventStream(samplingPeriod: _samplingPeriod)
        .listen((e) {
      _gx = e.x;
      _gy = e.y;
      _gz = e.z;
    });

    _accelSub = userAccelerometerEventStream(samplingPeriod: _samplingPeriod)
        .listen(_onAccel);

    // UI 갱신은 5Hz로 스로틀 (100Hz notify는 낭비)
    _uiTimer = Timer.periodic(
        const Duration(milliseconds: 200), (_) => notifyListeners());

    state = RecorderState.recording;
    notifyListeners();
  }

  void _onAccel(UserAccelerometerEvent e) {
    final ts = e.timestamp;
    if (_chunkEventStart == null) {
      _chunkEventStart = ts;
      _chunkWallStart = DateTime.now();
    }
    var dtMs = ts.difference(_chunkEventStart!).inMilliseconds;
    if (dtMs >= chunkMillis) {
      _finalizeChunk();
      _chunkEventStart = ts;
      _chunkWallStart = DateTime.now();
      dtMs = 0;
    }
    _buffer.add([dtMs, e.x, e.y, e.z, _gx, _gy, _gz]);
    totalSamples++;
    currentMagnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final secs = elapsed.inMilliseconds / 1000.0;
    if (secs > 0) effectiveHz = totalSamples / secs;
  }

  void _finalizeChunk() {
    if (_buffer.isEmpty || current == null) return;
    final chunk = SensorChunk(
      chunkIndex: chunkCount,
      startTs: _chunkWallStart ?? DateTime.now(),
      samples: _buffer,
      lat: lastFix?.latitude,
      lng: lastFix?.longitude,
      gpsAccuracyM: lastFix?.accuracy,
      speedMps: lastFix?.speed,
    );
    _buffer = [];
    chunkCount++;
    current!.chunkCount = chunkCount;
    // fire-and-forget append; 1Hz라 순서 꼬임 위험은 무시 가능한 수준이지만
    // 파일 append 자체는 flush로 순차 보장됨
    unawaited(_store.appendChunk(current!.localId, chunk));
  }

  Future<RecordedSession?> stop() async {
    if (state != RecorderState.recording || current == null) return null;

    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    await _posSub?.cancel();
    _uiTimer?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _posSub = null;
    _uiTimer = null;

    _finalizeChunk(); // 마지막 부분 청크 flush

    final session = current!;
    session.endedAt = DateTime.now();
    final secs =
        session.endedAt!.difference(session.startedAt).inMilliseconds / 1000.0;
    if (secs > 0) session.sampleRateHz = totalSamples / secs;
    session.chunkCount = chunkCount;
    await _store.saveMeta(session);

    await WakelockPlus.disable();
    state = RecorderState.idle;
    current = null;
    notifyListeners();
    return session;
  }

  Future<void> _startGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        gpsError = '위치 서비스 꺼짐';
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        gpsError = '위치 권한 없음';
        return;
      }
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(
        (pos) {
          lastFix = pos;
          gpsError = null;
        },
        onError: (Object e) => gpsError = 'GPS 오류',
      );
    } catch (_) {
      gpsError = 'GPS 초기화 실패';
    }
  }

  Future<String?> _deviceModel() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return 'Apple ${info.utsname.machine}';
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _posSub?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }
}
