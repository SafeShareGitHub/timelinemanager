import 'dart:convert';
import 'dart:html' as html;

/// Triggers a browser download of [contents] as [filename]. The returned
/// path is the blob URL — useful only for telemetry, not for I/O.
Future<String> saveTextFile(String filename, String contents) async {
  final bytes = utf8.encode(contents);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
