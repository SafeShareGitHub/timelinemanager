import 'dart:convert';
import 'dart:io';

import 'session_store.dart';

/// True when the platform can persist a session between runs.
const bool kSessionPersistenceSupported = true;

/// Returns the absolute path of the session file. Creates no directories.
String sessionFilePath() {
  final env = Platform.environment;
  final base = Platform.isWindows
      ? (env['APPDATA'] ?? env['USERPROFILE'])
      : (env['HOME'] ?? env['XDG_CONFIG_HOME']);
  final dir = (base == null || base.isEmpty)
      ? Directory.current.path
      : '$base${Platform.pathSeparator}timelinemanager';
  return '$dir${Platform.pathSeparator}session.json';
}

/// Reads and parses the session file. Returns null when the file is
/// missing, empty, or malformed — callers fall back to a seed.
SessionData? readSessionSync() {
  try {
    final file = File(sessionFilePath());
    if (!file.existsSync()) return null;
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final projects = ((map['projects'] as List?) ?? const [])
        .map((p) => SessionProject.fromJson(Map<String, dynamic>.from(p)))
        .toList(growable: false);
    if (projects.isEmpty) return null;
    final idx = (map['currentIndex'] as num?)?.toInt() ?? 0;
    return SessionData(idx.clamp(0, projects.length - 1), projects);
  } catch (_) {
    return null;
  }
}

/// Persists [data] atomically-ish: write to a sibling .tmp then rename, so
/// a crash mid-write can't leave a half-written session.json.
Future<void> writeSession(SessionData data) async {
  final path = sessionFilePath();
  final file = File(path);
  await file.parent.create(recursive: true);
  final payload = jsonEncode({
    'version': 1,
    'currentIndex': data.currentIndex,
    'projects': data.projects.map((p) => p.toJson()).toList(),
  });
  final tmp = File('$path.tmp');
  await tmp.writeAsString(payload, flush: true);
  await tmp.rename(path);
}

/// Terminates the process. The save button calls [writeSession] first.
Never quitApp() => exit(0);
