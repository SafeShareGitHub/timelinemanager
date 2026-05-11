import 'package:flutter/material.dart';
import 'package:timelinemanager/dialogues/newartifact.dart';
import 'package:timelinemanager/dialogues/opentimerange.dart';
import 'package:timelinemanager/state/filter_types.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

class TimelineToolbar extends StatelessWidget {
  final TimelineController controller;
  const TimelineToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: () => showNewArtifactDialog(context, c),
            icon: const Icon(Icons.add),
            label: const Text('Artifact'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: c.toggleLinkMode,
            icon: Icon(c.linkMode ? Icons.link_off : Icons.link),
            label: Text(c.linkMode ? 'Link-Modus AUS' : 'Link-Modus EIN'),
          ),
          const SizedBox(width: 16),
          const Text('px/Tag'),
          Slider(
            value: c.pxPerDay,
            min: 4,
            max: 40,
            onChanged: c.setPxPerDay,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => showTimeRangeDialog(context, c),
            icon: const Icon(Icons.date_range),
            label: const Text('Zeitraum'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              final days = c.endDate.difference(c.origin).inDays.abs();
              if (days > 0) {
                c.setPxPerDay(
                  ((MediaQuery.of(context).size.width - 200) / days)
                      .clamp(4, 200),
                );
              }
            },
            icon: const Icon(Icons.fit_screen),
            label: const Text('Fit to Range'),
          ),
          const SizedBox(width: 16),
          DropdownButton<String?>(
            value: c.typeFilter,
            hint: const Text('Typ-Filter'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Alle')),
              ...c.artifactTypes.map(
                (t) => DropdownMenuItem(value: t.key, child: Text(t.key)),
              ),
            ],
            onChanged: c.setTypeFilter,
          ),
          const SizedBox(width: 8),
          DropdownButton<ArtifactFilter>(
            value: c.artifactFilter,
            onChanged: (v) {
              if (v != null) c.setArtifactFilter(v);
            },
            items: const [
              DropdownMenuItem(
                value: ArtifactFilter.none,
                child: Text('Alle anzeigen'),
              ),
              DropdownMenuItem(
                value: ArtifactFilter.unlinked,
                child: Text('Nur unverlinkte'),
              ),
              DropdownMenuItem(
                value: ArtifactFilter.liegtVorOff,
                child: Text('Nur liegtVor = false'),
              ),
              DropdownMenuItem(
                value: ArtifactFilter.klarOff,
                child: Text('Nur klar = false'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Checkbox(
            value: c.dimFiltered,
            onChanged: (v) => c.setDimFiltered(v ?? false),
          ),
          const Text('statt Ausblenden: Dimmen'),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Suche Name/ID/Owner/Dok-ID',
              ),
              onChanged: c.setSearch,
            ),
          ),
        ],
      ),
    );
  }
}
