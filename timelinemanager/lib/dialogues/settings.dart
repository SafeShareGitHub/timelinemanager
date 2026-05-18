import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

/// Per-machine settings. Currently just the linked-file base path.
Future<void> showSettingsDialog(
  BuildContext context,
  TimelineController c,
) async {
  final pathC = TextEditingController(text: c.basePath);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Einstellungen'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basispfad für verknüpfte Dateien',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Wird vor relative "Verknüpfte Datei"-Einträge gehängt. '
              'Absolute Pfade (z.B. C:\\...) bleiben unverändert. '
              'Diese Einstellung ist pro Rechner — wird nicht mit der '
              'Sitzung exportiert.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathC,
              decoration: const InputDecoration(
                labelText: 'Basispfad',
                hintText: r'C:\SmarTeam\Work\',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            c.setBasePath(pathC.text);
            Navigator.pop(ctx);
          },
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
}
