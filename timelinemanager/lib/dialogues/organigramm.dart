import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/person.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/widgets/person_autocomplete_field.dart';

List<String> _distinct(Iterable<String> values) {
  final seen = <String>{};
  final out = <String>[];
  for (final v in values) {
    final t = v.trim();
    if (t.isNotEmpty && seen.add(t.toLowerCase())) out.add(t);
  }
  return out;
}

/// Org chart manager. Each entry is a person with an organisation and a
/// role; organisation and role intentionally repeat across people, so both
/// are auto-suggested from values already entered.
Future<void> showOrganigrammDialog(
  BuildContext context,
  TimelineController c,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final orgC = TextEditingController();
      final nameC = TextEditingController();
      final roleC = TextEditingController();
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final orgOptions = _distinct(c.people.map((p) => p.organisation));
          final roleOptions = _distinct(c.people.map((p) => p.role));

          // Group people by organisation for display.
          final byOrg = <String, List<Person>>{};
          for (final p in c.people) {
            (byOrg[p.organisation.trim()] ??= []).add(p);
          }
          final orgKeys = byOrg.keys.toList()..sort();

          Future<void> editPerson(Person p) async {
            final eo = TextEditingController(text: p.organisation);
            final en = TextEditingController(text: p.name);
            final er = TextEditingController(text: p.role);
            await showDialog<void>(
              context: ctx,
              builder: (c2) => AlertDialog(
                title: const Text('Person bearbeiten'),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PersonAutocompleteField(
                        controller: eo,
                        options: orgOptions,
                        decoration: const InputDecoration(
                          labelText: 'Organisation',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: en,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 8),
                      PersonAutocompleteField(
                        controller: er,
                        options: roleOptions,
                        decoration: const InputDecoration(labelText: 'Rolle'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c2),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (en.text.trim().isEmpty) return;
                      setLocal(() {
                        p.organisation = eo.text.trim();
                        p.name = en.text.trim();
                        p.role = er.text.trim();
                      });
                      c.commit(() {});
                      Navigator.pop(c2);
                    },
                    child: const Text('Speichern'),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('Organigramm'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.people.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Noch keine Personen angelegt.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    for (final org in orgKeys) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Text(
                          org.isEmpty ? '(ohne Organisation)' : org,
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                      ),
                      for (final p in byOrg[org]!)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline),
                          title: Text(p.name),
                          subtitle: Text(
                            p.role.isEmpty ? '(ohne Rolle)' : p.role,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Bearbeiten',
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => editPerson(p),
                              ),
                              IconButton(
                                tooltip: 'Löschen',
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                onPressed: () {
                                  setLocal(() => c.people.remove(p));
                                  c.commit(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                    const Divider(height: 24),
                    Text(
                      'Person hinzufügen',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    PersonAutocompleteField(
                      controller: orgC,
                      options: orgOptions,
                      decoration: const InputDecoration(
                        labelText: 'Organisation / Stakeholder',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 8),
                    PersonAutocompleteField(
                      controller: roleC,
                      options: roleOptions,
                      decoration: const InputDecoration(labelText: 'Rolle'),
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
              FilledButton.icon(
                onPressed: () {
                  if (nameC.text.trim().isEmpty) return;
                  setLocal(() {
                    c.people.add(
                      Person(
                        organisation: orgC.text.trim(),
                        name: nameC.text.trim(),
                        role: roleC.text.trim(),
                      ),
                    );
                    nameC.clear();
                  });
                  c.commit(() {});
                },
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
            ],
          );
        },
      );
    },
  );
}
