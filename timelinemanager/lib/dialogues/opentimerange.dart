import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/utils/date_utils.dart';

Future<void> showTimeRangeDialog(
  BuildContext context,
  TimelineController c,
) async {
  DateTime s = c.origin;
  DateTime e = c.endDate;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Zeitraum einstellen'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Start:'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: s,
                    );
                    if (p != null) s = p;
                  },
                  child: Text(fmtDate(s)),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Ende :'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: e,
                    );
                    if (p != null) e = p;
                  },
                  child: Text(fmtDate(e)),
                ),
              ],
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
            c.setTimeRange(s, e);
            Navigator.pop(ctx);
          },
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
}
