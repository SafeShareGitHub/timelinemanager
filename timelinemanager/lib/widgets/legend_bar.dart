import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

class LegendBar extends StatelessWidget {
  final TimelineController controller;
  const LegendBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, -2),
            color: Color(0x14000000),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Text('Legende:'),
          const SizedBox(width: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final t in c.artifactTypes)
                Chip(
                  label: Text(
                    t.key,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: t.color.withOpacity(0.95),
                ),
            ],
          ),
          const Spacer(),
          if (c.focusArtifactId != null)
            Row(
              children: [
                const Icon(Icons.highlight_alt, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Fokus: ${c.focusArtifactId} (${c.focusDimOthers ? "dimmen" : "ausblenden"})',
                ),
                const SizedBox(width: 14),
              ],
            ),
          Row(
            children: [
              Icon(
                c.bandStackMode
                    ? Icons.view_agenda_outlined
                    : Icons.layers_outlined,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                c.bandStackMode ? 'Bands: gestapelt' : 'Bands: überlappend',
              ),
              const SizedBox(width: 12),
              const Icon(Icons.push_pin_outlined, size: 18),
              const SizedBox(width: 6),
              Text('Events: ${c.events.length}'),
            ],
          ),
          const SizedBox(width: 16),
          Text('Artefakte: ${c.artifacts.length} · Links: ${c.links.length}'),
        ],
      ),
    );
  }
}
