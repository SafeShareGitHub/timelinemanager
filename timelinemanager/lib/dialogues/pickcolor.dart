import 'package:flutter/material.dart';

Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initial,
}) async {
  Color chosen = initial;
  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Farbe wählen'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in Colors.primaries)
            GestureDetector(
              onTap: () => chosen = c,
              onDoubleTap: () => Navigator.pop(ctx, c),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: c,
                child: c == chosen
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, chosen),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
