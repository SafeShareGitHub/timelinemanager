export 'external_open_io.dart' if (dart.library.html) 'external_open_web.dart';

/// Result of an attempt to open a file via the host OS.
class ExternalOpenResult {
  final bool ok;
  final String? error;
  const ExternalOpenResult.success() : ok = true, error = null;
  const ExternalOpenResult.failure(String this.error) : ok = false;
}
