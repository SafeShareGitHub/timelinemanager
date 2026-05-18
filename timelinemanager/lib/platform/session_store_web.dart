import 'dart:convert';
import 'dart:html' as html;

import 'session_store.dart';

const bool kSessionPersistenceSupported = false;

String sessionFilePath() => '';
String snapshotsDirPath() => '';

SessionData? readSessionSync() => null;
SessionData? readSessionAtPathSync(String path) => null;

SessionData? parseSessionFromJson(String text) {
  try {
    if (text.trim().isEmpty) return null;
    final map = jsonDecode(text) as Map<String, dynamic>;
    final projects = ((map['projects'] as List?) ?? const [])
        .map((p) => SessionProject.fromJson(Map<String, dynamic>.from(p)))
        .toList(growable: false);
    if (projects.isEmpty) return null;
    final idx = (map['currentIndex'] as num?)?.toInt() ?? 0;
    return SessionData(
      idx.clamp(0, projects.length - 1),
      projects,
      basePath: (map['basePath'] as String?) ?? '',
    );
  } catch (_) {
    return null;
  }
}

Future<void> writeSession(SessionData data) async {}

Future<String> writeDailySnapshot(SessionData data) async => '';

List<SnapshotEntry> listSnapshots() => const [];

/// Closing a tab from JS is blocked in most browsers; this is a best-effort
/// fallback so the same call site works on web.
Never quitApp() {
  html.window.close();
  throw StateError('quitApp returned on web');
}
