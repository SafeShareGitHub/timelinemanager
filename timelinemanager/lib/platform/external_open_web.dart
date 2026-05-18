import 'dart:html' as html;

import 'external_open.dart';

/// Web sandbox can't shell-open a local path. Tell the caller cleanly.
Future<ExternalOpenResult> openExternally(String path) async =>
    const ExternalOpenResult.failure(
      'Externe Dateien sind im Web-Build nicht verfügbar.',
    );

/// Opens a web link in a new browser tab. A missing scheme gets `https://`
/// prepended so `example.com` still works.
Future<ExternalOpenResult> openUrlExternally(String url) async {
  var u = url.trim();
  if (u.isEmpty) {
    return const ExternalOpenResult.failure('Kein Link angegeben.');
  }
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(u)) {
    u = 'https://$u';
  }
  try {
    html.window.open(u, '_blank');
    return const ExternalOpenResult.success();
  } catch (e) {
    return ExternalOpenResult.failure('$e');
  }
}
