import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/classes/todo.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/utils/date_utils.dart';
import 'package:timelinemanager/widgets/linked_files_field.dart';
import 'package:timelinemanager/widgets/person_autocomplete_field.dart';
import 'package:timelinemanager/widgets/todo_list_editor.dart';
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
  final fileCs = <TextEditingController>[];
  String type = c.artifactTypes.isNotEmpty ? c.artifactTypes.first.key : 'Other';
  DateTime date = DateTime.now();
  final chosenBands = <String>{};
  final chosenEvents = <String>{};
  final chosenGates = <String>{};
  final todos = <TodoItem>[];

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
                PersonAutocompleteField(
                  controller: ownerC,
                  options: c.personNames,
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
                LinkedFilesField(
                  controllers: fileCs,
                  setLocal: setLocal,
                  c: c,
                  showOpenButtons: false,
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
                TodoListEditor(
                  todos: todos,
                  setLocal: setLocal,
                  personNames: c.personNames,
                ),
                const Divider(height: 18),
                Text(
                  'Quality Gates',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                if (c.qualityGates.isEmpty)
                  const Text(
                    'Keine Quality Gates definiert — oben rechts anlegen.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final qg in c.qualityGates)
                      FilterChip(
                        avatar: const Icon(Icons.verified_outlined, size: 16),
                        label: Text(qg.name),
                        selected: chosenGates.contains(qg.id),
                        onSelected: (v) => setLocal(
                          () => v
                              ? chosenGates.add(qg.id)
                              : chosenGates.remove(qg.id),
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
                qualityGateIds: chosenGates.toList(),
                todos: todos,
                klar: klar,
                liegtVor: liegtVor,
                linkedFiles: readLinkedFileControllers(fileCs),
              );
              c.addArtifact(newArt, const <String>{}, const <String>{});
              Navigator.pop(ctx);
            },
            child: const Text('Anlegen'),
          ),
        ],
      ),
    ),
  );
}
