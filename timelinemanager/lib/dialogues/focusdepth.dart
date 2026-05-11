import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

Future<void> showFocusDepthDialog(
  BuildContext context,
  TimelineController c,
) async {
  int tempDepth = c.focusDepth;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Fokus-Tiefe einstellen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Wie viele Nachbar-Ebenen anzeigen?'),
            Slider(
              value: tempDepth.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$tempDepth',
              onChanged: (v) => setLocal(() => tempDepth = v.round()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              c.setFocusDepth(tempDepth);
              Navigator.pop(ctx);
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
}
