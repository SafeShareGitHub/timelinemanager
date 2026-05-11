import 'dart:io';

/// Saves [contents] to a file named [filename] in the user's Downloads
/// folder (or the home directory if Downloads is unavailable, or the
/// current working directory as a last resort). Returns the absolute path
/// of the written file.
Future<String> saveTextFile(String filename, String contents) async {
  final dir = _resolveDownloadsDir();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(contents);
  return file.path;
}

Directory _resolveDownloadsDir() {
  final env = Platform.environment;
  final home = Platform.isWindows
      ? env['USERPROFILE']
      : (env['HOME'] ?? env['XDG_CONFIG_HOME']);
  if (home != null && home.isNotEmpty) {
    final downloads = Directory('$home${Platform.pathSeparator}Downloads');
    if (downloads.existsSync()) return downloads;
    final fallback = Directory(home);
    if (fallback.existsSync()) return fallback;
  }
  return Directory.current;
}
