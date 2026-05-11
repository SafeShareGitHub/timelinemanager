import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

Future<void> showYearFilterDialog(
  BuildContext context,
  TimelineController c,
) async {
  int sYear = c.origin.year;
  int eYear = c.endDate.year;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Jahresfilter'),
      content: SizedBox(
        width: 420,
        child: Row(
          children: [
            Expanded(
              child: _yearField('Startjahr', sYear, (v) {
                final n = int.tryParse(v);
                if (n != null) sYear = n;
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _yearField('Endjahr', eYear, (v) {
                final n = int.tryParse(v);
                if (n != null) eYear = n;
              }),
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
            if (eYear < sYear) eYear = sYear;
            c.setTimeRange(DateTime(sYear, 1, 1), DateTime(eYear, 12, 31));
            Navigator.pop(ctx);
          },
          child: const Text('Anwenden'),
        ),
      ],
    ),
  );
}

Widget _yearField(String label, int value, ValueChanged<String> onChanged) =>
    TextField(
      controller: TextEditingController(text: '$value'),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
