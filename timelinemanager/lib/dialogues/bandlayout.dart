import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

Future<void> showBandLayoutDialog(
  BuildContext context,
  TimelineController c,
) async {
  bool stack = c.bandStackMode;
  double opacity = c.bandOpacity;
  double rowH = c.bandRowHeight;
  double rowG = c.bandRowGap;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Band-Layout'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Gestapelt (statt Überlappen)'),
                value: stack,
                onChanged: (v) => setLocal(() => stack = v),
              ),
              if (!stack) ...[
                const SizedBox(height: 8),
                const Text('Deckkraft bei Überlappung'),
                Slider(
                  min: 0.2,
                  max: 1.0,
                  divisions: 8,
                  value: opacity,
                  label: opacity.toStringAsFixed(2),
                  onChanged: (v) => setLocal(() => opacity = v),
                ),
              ],
              if (stack) ...[
                const SizedBox(height: 8),
                const Text('Reihenhöhe'),
                Slider(
                  min: 14,
                  max: 36,
                  divisions: 11,
                  value: rowH,
                  label: '${rowH.round()} px',
                  onChanged: (v) => setLocal(() => rowH = v),
                ),
                const SizedBox(height: 8),
                const Text('Abstand zwischen Reihen'),
                Slider(
                  min: 2,
                  max: 16,
                  divisions: 14,
                  value: rowG,
                  label: '${rowG.round()} px',
                  onChanged: (v) => setLocal(() => rowG = v),
                ),
              ],
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
              c.applyBandLayout(
                stack: stack,
                opacity: opacity,
                rowH: rowH,
                rowG: rowG,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    ),
  );
}
