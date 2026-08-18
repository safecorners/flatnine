/// 1초 분량의 센서 샘플 묶음. 서버의 `sensor_chunks` 1행과 1:1 대응.
class SensorChunk {
  final int chunkIndex;
  final DateTime startTs;

  /// [[dt_ms, ax, ay, az, gx, gy, gz], ...]
  /// 선형가속도(m/s², 중력 제거) + 자이로(rad/s). dt_ms는 청크 시작 기준 오프셋.
  final List<List<num>> samples;

  final double? lat;
  final double? lng;
  final double? gpsAccuracyM;
  final double? speedMps;

  SensorChunk({
    required this.chunkIndex,
    required this.startTs,
    required this.samples,
    this.lat,
    this.lng,
    this.gpsAccuracyM,
    this.speedMps,
  });

  Map<String, dynamic> toJson() => {
        'chunk_index': chunkIndex,
        'start_ts': startTs.toUtc().toIso8601String(),
        'samples': samples,
        'lat': lat,
        'lng': lng,
        'gps_accuracy_m': gpsAccuracyM,
        'speed_mps': speedMps,
      };

  factory SensorChunk.fromJson(Map<String, dynamic> json) => SensorChunk(
        chunkIndex: json['chunk_index'] as int,
        startTs: DateTime.parse(json['start_ts'] as String),
        samples: (json['samples'] as List)
            .map((row) => (row as List).cast<num>())
            .toList(),
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        gpsAccuracyM: (json['gps_accuracy_m'] as num?)?.toDouble(),
        speedMps: (json['speed_mps'] as num?)?.toDouble(),
      );

  /// Supabase `sensor_chunks` insert 행
  Map<String, dynamic> toRow(String sessionId) => {
        'session_id': sessionId,
        'chunk_index': chunkIndex,
        'start_ts': startTs.toUtc().toIso8601String(),
        'n_samples': samples.length,
        'samples': samples,
        'lat': lat,
        'lng': lng,
        'gps_accuracy_m': gpsAccuracyM,
        'speed_mps': speedMps,
      };
}
