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

/// Returns the absolute path of the snapshots directory (no I/O).
String snapshotsDirPath() {
  final parent = File(sessionFilePath()).parent.path;
  return '$parent${Platform.pathSeparator}snapshots';
}

/// Reads and parses the session file. Returns null when the file is
/// missing, empty, or malformed — callers fall back to a seed.
SessionData? readSessionSync() {
  try {
    final file = File(sessionFilePath());
    if (!file.existsSync()) return null;
    return _parseSession(file.readAsStringSync());
  } catch (_) {
    return null;
  }
}

/// Reads any session file at [path]. Same parsing rules as [readSessionSync].
SessionData? readSessionAtPathSync(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return _parseSession(file.readAsStringSync());
  } catch (_) {
    return null;
  }
}

/// Parses a session JSON string directly (for the paste-text restore flow).
SessionData? parseSessionFromJson(String text) {
  try {
    return _parseSession(text);
  } catch (_) {
    return null;
  }
}

SessionData? _parseSession(String raw) {
  if (raw.trim().isEmpty) return null;
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final projects = ((map['projects'] as List?) ?? const [])
      .map((p) => SessionProject.fromJson(Map<String, dynamic>.from(p)))
      .toList(growable: false);
  if (projects.isEmpty) return null;
  final idx = (map['currentIndex'] as num?)?.toInt() ?? 0;
  return SessionData(idx.clamp(0, projects.length - 1), projects);
}

/// Persists [data] atomically-ish: write to a sibling .tmp then rename, so
/// a crash mid-write can't leave a half-written session.json.
Future<void> writeSession(SessionData data) async {
  final path = sessionFilePath();
  final file = File(path);
  await file.parent.create(recursive: true);
  final payload = _encodeSession(data);
  final tmp = File('$path.tmp');
  await tmp.writeAsString(payload, flush: true);
  await tmp.rename(path);
}

/// Writes the current session as a dated snapshot. Same-day clicks
/// overwrite the day's file; a new day creates a new one. Returns the
/// absolute path of the snapshot file.
Future<String> writeDailySnapshot(SessionData data) async {
  final dir = Directory(snapshotsDirPath());
  await dir.create(recursive: true);
  final now = DateTime.now();
  final ymd =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final path = '${dir.path}${Platform.pathSeparator}session_$ymd.json';
  final payload = _encodeSession(data);
  final tmp = File('$path.tmp');
  await tmp.writeAsString(payload, flush: true);
  await tmp.rename(path);
  return path;
}

/// Lists snapshot files newest-first. Files that fail to parse are still
/// included with `projectCount = 0` so the user sees they exist.
List<SnapshotEntry> listSnapshots() {
  try {
    final dir = Directory(snapshotsDirPath());
    if (!dir.existsSync()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    final entries = files.map((f) {
      var count = 0;
      try {
        final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        count = ((map['projects'] as List?) ?? const []).length;
      } catch (_) {}
      return SnapshotEntry(
        path: f.path,
        name: f.uri.pathSegments.last,
        modified: f.lastModifiedSync(),
        projectCount: count,
      );
    }).toList();
    entries.sort((a, b) => b.modified.compareTo(a.modified));
    return entries;
  } catch (_) {
    return const [];
  }
}

String _encodeSession(SessionData data) => jsonEncode({
  'version': 1,
  'currentIndex': data.currentIndex,
  'projects': data.projects.map((p) => p.toJson()).toList(),
});

/// Terminates the process. The save button calls [writeSession] first.
Never quitApp() => exit(0);
