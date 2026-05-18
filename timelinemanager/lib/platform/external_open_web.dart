import 'external_open.dart';

/// Web sandbox can't shell-open a local path. Tell the caller cleanly.
Future<ExternalOpenResult> openExternally(String path) async =>
    const ExternalOpenResult.failure(
      'Externe Dateien sind im Web-Build nicht verfügbar.',
    );
