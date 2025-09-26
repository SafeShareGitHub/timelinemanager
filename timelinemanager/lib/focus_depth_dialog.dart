import 'package:flutter/material.dart';

class FocusDepthDialog extends StatefulWidget {
  final int initialDepth;
  const FocusDepthDialog({super.key, required this.initialDepth});

  @override
  State<FocusDepthDialog> createState() => _FocusDepthDialogState();

  // Optional static opener if you prefer calling: FocusDepthDialog.show(...)
  static Future<int?> show(BuildContext context, {required int initialDepth}) {
    return showDialog<int>(
      context: context,
      builder: (_) => FocusDepthDialog(initialDepth: initialDepth),
    );
  }
}

class _FocusDepthDialogState extends State<FocusDepthDialog> {
  late int tempDepth;

  @override
  void initState() {
    super.initState();
    tempDepth = widget.initialDepth;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            onChanged: (v) => setState(() => tempDepth = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, tempDepth), child: const Text('Übernehmen')),
      ],
    );
  }
}

// Top-level helper (alternative to the static method above)
Future<int?> showFocusDepthDialog(BuildContext context, int initialDepth) {
  return showDialog<int>(
    context: context,
    builder: (_) => FocusDepthDialog(initialDepth: initialDepth),
  );
}
