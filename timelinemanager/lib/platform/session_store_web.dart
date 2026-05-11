import 'dart:html' as html;

import 'session_store.dart';

const bool kSessionPersistenceSupported = false;

String sessionFilePath() => '';

SessionData? readSessionSync() => null;

Future<void> writeSession(SessionData data) async {}

/// Closing a tab from JS is blocked in most browsers; this is a best-effort
/// fallback so the same call site works on web.
Never quitApp() {
  html.window.close();
  throw StateError('quitApp returned on web');
}
