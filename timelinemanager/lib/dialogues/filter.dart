import 'package:flutter/material.dart';
import 'package:timelinemanager/state/filter_types.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

Future<void> showPhaseEventFilterDialog(
  BuildContext context,
  TimelineController c,
) async {
  final tempBands = {...c.selectedBandIds};
  final tempEvents = {...c.selectedEventIds};
  FilterMode tempMode = c.filterMode;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Filter (Phasen & Events)'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Modus'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Ignorieren'),
                      selected: tempMode == FilterMode.ignore,
                      onSelected: (_) =>
                          setLocal(() => tempMode = FilterMode.ignore),
                    ),
                    ChoiceChip(
                      label: const Text('Nur ausgewählte zeigen'),
                      selected: tempMode == FilterMode.showOnly,
                      onSelected: (_) =>
                          setLocal(() => tempMode = FilterMode.showOnly),
                    ),
                    ChoiceChip(
                      label: const Text('Ausgewählte ausblenden'),
                      selected: tempMode == FilterMode.hideSelected,
                      onSelected: (_) =>
                          setLocal(() => tempMode = FilterMode.hideSelected),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text(
                  'Phasen (${c.bands.length})',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in c.bands)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: b.color,
                          radius: 8,
                        ),
                        label: Text(b.label),
                        selected: tempBands.contains(b.id),
                        onSelected: (v) => setLocal(() {
                          if (v) {
                            tempBands.add(b.id);
                          } else {
                            tempBands.remove(b.id);
                          }
                        }),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Text(
                  'Events (${c.events.length})',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in c.events)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: e.color,
                          radius: 8,
                        ),
                        label: Text(e.label),
                        selected: tempEvents.contains(e.id),
                        onSelected: (v) => setLocal(() {
                          if (v) {
                            tempEvents.add(e.id);
                          } else {
                            tempEvents.remove(e.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
          FilledButton(
            onPressed: () {
              c.applyFilters(
                bands: tempBands,
                events: tempEvents,
                mode: tempMode,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Anwenden'),
          ),
        ],
      ),
    ),
  );
}
