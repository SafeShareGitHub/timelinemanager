import 'package:flutter/material.dart';
import 'package:timelinemanager/platform/file_export.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

/// Exports the controller's current state as a .txt file. On web the
/// browser triggers a download; on desktop the file lands in the user's
/// Downloads folder and a snackbar shows the absolute path.
Future<void> exportTimelineToJson(
  BuildContext context,
  TimelineController c,
) async {
  final data = c.serialize();

  final now = DateTime.now();
  final time =
      '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final safeTitle =
      c.timelineTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  final filename = '${safeTitle}_$date _$time.txt';

  try {
    final path = await saveTextFile(filename, data);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export gespeichert: $path')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export-Fehler: $e')),
    );
  }
}
