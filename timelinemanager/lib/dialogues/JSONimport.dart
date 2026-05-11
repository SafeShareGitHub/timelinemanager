import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

Future<void> showJsonImportDialog(
  BuildContext context,
  TimelineController c,
) async {
  final controller = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import JSON'),
      content: SizedBox(
        width: 640,
        child: TextField(
          controller: controller,
          maxLines: 18,
          decoration: const InputDecoration(
            hintText: 'JSON hier einfügen...',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            try {
              c.importJson(controller.text);
              Navigator.pop(ctx);
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Import-Fehler: $e')));
            }
          },
          child: const Text('Importieren'),
        ),
      ],
    ),
  );
}
