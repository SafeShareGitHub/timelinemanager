import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/dialogues/editlink.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/utils/date_utils.dart';
import 'package:timelinemanager/widgets/linked_files_field.dart';
import 'package:timelinemanager/widgets/person_autocomplete_field.dart';
import 'package:timelinemanager/widgets/todo_list_editor.dart';
import 'package:timelinemanager/widgets/type_dropdown.dart';

Future<void> showEditArtifactDialog(
  BuildContext context,
  TimelineController c,
  Artifact a,
) async {
  final nameC = TextEditingController(text: a.name);
  final ownerC = TextEditingController(text: a.owner);
  final docC = TextEditingController(text: a.documentId);
  final notesC = TextEditingController(text: a.notes);
  final fileCs = makeLinkedFileControllers(a.linkedFiles);
  String type = a.type;
  DateTime date = a.date;
  final chosenBands = a.bandIds.toSet();
  final chosenEvents = a.eventIds.toSet();
  final chosenGates = a.qualityGateIds.toSet();
  final todos = a.todos.map((t) => t.copy()).toList();

  bool klar = a.klar;
  bool liegtVor = a.liegtVor;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.95,
          child: Scaffold(
            appBar: AppBar(title: Text('Artefakt bearbeiten: ${a.id}')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TypeDropdown(
                    types: c.artifactTypes,
                    value: type,
                    onChanged: (v) => type = v ?? type,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Datum:'),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: docC,
                    decoration: const InputDecoration(
                      labelText: 'Dokument-ID',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesC,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notizen'),
                  ),
                  const SizedBox(height: 12),
                  LinkedFilesField(
                    controllers: fileCs,
                    setLocal: setLocal,
                    c: c,
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  TodoListEditor(
                    todos: todos,
                    setLocal: setLocal,
                    personNames: c.personNames,
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
                  const Text('Verknüpfte Links'),
                  const SizedBox(height: 6),
                  ...c.links
                      .where((l) => l.fromId == a.id || l.toId == a.id)
                      .map(
                        (l) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.link),
                          title: Text('${l.fromId} → ${l.toId}'),
                          subtitle: Text(
                            l.label.isEmpty ? '(ohne Label)' : l.label,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Label bearbeiten',
                                icon: const Icon(Icons.edit),
                                onPressed: () => showEditLinkDialog(ctx, c, l),
                              ),
                              IconButton(
                                tooltip: 'Link löschen',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => c.deleteLink(l),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          c.deleteArtifact(a);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Artefakt löschen'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          c.commit(() {
                            a.name = nameC.text.trim();
                            a.type = type;
                            a.owner = ownerC.text.trim();
                            a.documentId = docC.text.trim();
                            a.notes = notesC.text.trim();
                            a.linkedFiles = readLinkedFileControllers(fileCs);
                            a.date = date;
                            a.bandIds = chosenBands.toList();
                            a.eventIds = chosenEvents.toList();
                            a.qualityGateIds = chosenGates.toList();
                            a.todos = todos;
                            a.klar = klar;
                            a.liegtVor = liegtVor;
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Speichern'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
