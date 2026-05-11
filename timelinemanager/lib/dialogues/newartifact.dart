import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/utils/date_utils.dart';
import 'package:timelinemanager/widgets/type_dropdown.dart';

Future<void> showNewArtifactDialog(
  BuildContext context,
  TimelineController c,
) async {
  final nameC = TextEditingController();
  final idC = TextEditingController();
  final ownerC = TextEditingController();
  final docC = TextEditingController();
  final notesC = TextEditingController();
  String type = c.artifactTypes.isNotEmpty ? c.artifactTypes.first.key : 'Other';
  DateTime date = DateTime.now();
  final chosenBands = <String>{};
  final chosenEvents = <String>{};

  final inboundSel = <String>{};
  final outboundSel = <String>{};

  bool klar = false;
  bool liegtVor = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Neues Artefakt'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TypeDropdown(
                  types: c.artifactTypes,
                  value: type,
                  onChanged: (v) => type = v ?? type,
                ),
                Row(
                  children: [
                    const Text('Datum:'),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: date,
                        );
                        if (p != null) setLocal(() => date = p);
                      },
                      child: Text(fmtDate(date)),
                    ),
                  ],
                ),
                TextField(
                  controller: ownerC,
                  decoration: const InputDecoration(
                    labelText: 'Ansprechpartner',
                  ),
                ),
                TextField(
                  controller: docC,
                  decoration: const InputDecoration(labelText: 'Dokument-ID'),
                ),
                TextField(
                  controller: notesC,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notizen'),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: klar,
                  onChanged: (v) => setLocal(() => klar = v ?? false),
                  title: const Text('klar'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: liegtVor,
                  onChanged: (v) => setLocal(() => liegtVor = v ?? false),
                  title: const Text('liegt vor'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 18),
                Text(
                  'Inputs (wählen → Link von Quelle → dieses Artefakt)',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in c.artifacts)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: c.typeByKey(a.type).color,
                          radius: 8,
                        ),
                        label: Text(a.id),
                        selected: inboundSel.contains(a.id),
                        onSelected: (v) => setLocal(
                          () => v
                              ? inboundSel.add(a.id)
                              : inboundSel.remove(a.id),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Outputs (wählen → Link von diesem Artefakt → Ziel)',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in c.artifacts)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: c.typeByKey(a.type).color,
                          radius: 8,
                        ),
                        label: Text(a.id),
                        selected: outboundSel.contains(a.id),
                        onSelected: (v) => setLocal(
                          () => v
                              ? outboundSel.add(a.id)
                              : outboundSel.remove(a.id),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 18),
                Text(
                  'Phasen-Zuordnung',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
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
                        selected: chosenBands.contains(b.id),
                        onSelected: (v) => setLocal(
                          () => v
                              ? chosenBands.add(b.id)
                              : chosenBands.remove(b.id),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Event-Zuordnung',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
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
                        selected: chosenEvents.contains(e.id),
                        onSelected: (v) => setLocal(
                          () => v
                              ? chosenEvents.add(e.id)
                              : chosenEvents.remove(e.id),
                        ),
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
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;

              String id = idC.text.trim();
              if (id.isEmpty) {
                final rnd = math.Random();
                do {
                  id = 'R-${rnd.nextInt(1000000)}';
                } while (c.artifacts.any((a) => a.id == id));
              }

              final newArt = Artifact(
                id: id,
                name: nameC.text.trim(),
                type: type,
                owner: ownerC.text.trim(),
                documentId: docC.text.trim(),
                date: date,
                y: 120 + (c.artifacts.length % 6) * 80,
                notes: notesC.text.trim(),
                bandIds: chosenBands.toList(),
                eventIds: chosenEvents.toList(),
                inputs: inboundSel.toList(),
                outputs: outboundSel.toList(),
                klar: klar,
                liegtVor: liegtVor,
              );
              c.addArtifact(newArt, inboundSel, outboundSel);
              Navigator.pop(ctx);
            },
            child: const Text('Anlegen'),
          ),
        ],
      ),
    ),
  );
}
