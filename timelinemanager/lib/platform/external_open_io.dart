import 'dart:io';

import 'external_open.dart';

/// Hands [path] to the OS's default handler for the file's extension. On
/// Windows this routes .xlsm → Excel, .pdf → your PDF viewer, etc. No
/// elevation, no Developer Mode, no plugin: just a child process.
Future<ExternalOpenResult> openExternally(String path) async {
  if (path.trim().isEmpty) {
    return const ExternalOpenResult.failure('Kein Pfad angegeben.');
  }
  try {
    if (!await File(path).exists() && !await Directory(path).exists()) {
      return ExternalOpenResult.failure('Datei nicht gefunden: $path');
    }
    if (Platform.isWindows) {
      // `cmd /c start "" "<path>"` is the canonical Windows shell-execute.
      // The empty "" is the window-title slot — without it, start would
      // treat a quoted path as the title.
      final result = await Process.run(
        'cmd',
        ['/c', 'start', '', path],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        return ExternalOpenResult.failure(
          'Start fehlgeschlagen (Exit ${result.exitCode}): ${result.stderr}',
        );
      }
      return const ExternalOpenResult.success();
    }
    if (Platform.isMacOS) {
      final r = await Process.run('open', [path]);
      return r.exitCode == 0
          ? const ExternalOpenResult.success()
          : ExternalOpenResult.failure(r.stderr.toString());
    }
    if (Platform.isLinux) {
      final r = await Process.run('xdg-open', [path]);
      return r.exitCode == 0
          ? const ExternalOpenResult.success()
          : ExternalOpenResult.failure(r.stderr.toString());
    }
    return const ExternalOpenResult.failure('Plattform nicht unterstützt.');
  } catch (e) {
    return ExternalOpenResult.failure('$e');
  }
}

/// Opens a web link in the user's default browser. A missing scheme gets
/// `https://` prepended so `example.com` still works.
Future<ExternalOpenResult> openUrlExternally(String url) async {
  final u = _normalizeUrl(url);
  if (u.isEmpty) {
    return const ExternalOpenResult.failure('Kein Link angegeben.');
  }
  try {
    if (Platform.isWindows) {
      final result = await Process.run(
        'cmd',
        ['/c', 'start', '', u],
        runInShell: false,
      );
      return result.exitCode == 0
          ? const ExternalOpenResult.success()
          : ExternalOpenResult.failure(
              'Start fehlgeschlagen (Exit ${result.exitCode}).',
            );
    }
    if (Platform.isMacOS) {
      final r = await Process.run('open', [u]);
      return r.exitCode == 0
          ? const ExternalOpenResult.success()
          : ExternalOpenResult.failure(r.stderr.toString());
    }
    if (Platform.isLinux) {
      final r = await Process.run('xdg-open', [u]);
      return r.exitCode == 0
          ? const ExternalOpenResult.success()
          : ExternalOpenResult.failure(r.stderr.toString());
    }
    return const ExternalOpenResult.failure('Plattform nicht unterstützt.');
  } catch (e) {
    return ExternalOpenResult.failure('$e');
  }
}

String _normalizeUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s)) {
    s = 'https://$s';
  }
  return s;
}
