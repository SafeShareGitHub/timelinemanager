import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/link.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

Future<void> showEditLinkDialog(
  BuildContext context,
  TimelineController c,
  Link l,
) async {
  final labelC = TextEditingController(text: l.label);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Link bearbeiten: ${l.id}'),
      content: TextField(
        controller: labelC,
        decoration: const InputDecoration(labelText: 'Label'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            c.deleteLink(l);
            Navigator.pop(ctx);
          },
          child: const Text('Löschen'),
        ),
        FilledButton(
          onPressed: () {
            c.commit(() => l.label = labelC.text.trim());
            Navigator.pop(ctx);
          },
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
}
