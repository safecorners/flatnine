import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/recorded_session.dart';
import '../models/sensor_chunk.dart';

/// 세션을 앱 문서 디렉토리에 영속한다.
/// `sessions/<localId>/meta.json` — 세션 메타 (상태 바뀔 때마다 재작성)
/// `sessions/<localId>/chunks.jsonl` — 청크당 1줄 append (크래시 대비)
class SessionStore {
  Directory? _rootCache;

  Future<Directory> _root() async {
    if (_rootCache != null) return _rootCache!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sessions');
    await dir.create(recursive: true);
    _rootCache = dir;
    return dir;
  }

  Future<Directory> _sessionDir(String localId) async {
    final dir = Directory('${(await _root()).path}/$localId');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> saveMeta(RecordedSession session) async {
    final dir = await _sessionDir(session.localId);
    await File('${dir.path}/meta.json')
        .writeAsString(jsonEncode(session.toJson()));
  }

  Future<void> appendChunk(String localId, SensorChunk chunk) async {
    final dir = await _sessionDir(localId);
    await File('${dir.path}/chunks.jsonl').writeAsString(
      '${jsonEncode(chunk.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<List<SensorChunk>> readChunks(String localId) async {
    final dir = await _sessionDir(localId);
    final file = File('${dir.path}/chunks.jsonl');
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    return [
      for (final line in lines)
        if (line.trim().isNotEmpty)
          SensorChunk.fromJson(jsonDecode(line) as Map<String, dynamic>),
    ];
  }

  Future<List<RecordedSession>> list() async {
    final root = await _root();
    final sessions = <RecordedSession>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final metaFile = File('${entry.path}/meta.json');
      if (!await metaFile.exists()) continue;
      try {
        sessions.add(RecordedSession.fromJson(
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>));
      } catch (_) {
        // 손상된 메타는 목록에서 제외
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<void> delete(String localId) async {
    final dir = await _sessionDir(localId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
