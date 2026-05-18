import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/qualitygate.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

/// Quality-gate manager. Gates defined here can be assigned to artifacts;
/// typing a gate name (e.g. "QG1") into the search box then surfaces every
/// artifact assigned to it.
Future<void> showManageQualityGatesDialog(
  BuildContext context,
  TimelineController c,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final nameC = TextEditingController();
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Quality Gates verwalten'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.qualityGates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Noch keine Quality Gates angelegt.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  for (final qg in c.qualityGates)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.verified_outlined),
                      title: Text(qg.name),
                      subtitle: Text(
                        '${c.artifacts.where((a) => a.qualityGateIds.contains(qg.id)).length} Artefakt(e) zugewiesen',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Umbenennen',
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () async {
                              final nc =
                                  TextEditingController(text: qg.name);
                              await showDialog<void>(
                                context: ctx,
                                builder: (c2) => AlertDialog(
                                  title: const Text('Quality Gate umbenennen'),
                                  content: TextField(
                                    controller: nc,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c2),
                                      child: const Text('Abbrechen'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        if (nc.text.trim().isEmpty) return;
                                        setLocal(
                                            () => qg.name = nc.text.trim());
                                        c.commit(() {});
                                        Navigator.pop(c2);
                                      },
                                      child: const Text('Speichern'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Löschen',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () {
                              setLocal(() {
                                c.qualityGates.remove(qg);
                                for (final a in c.artifacts) {
                                  a.qualityGateIds.remove(qg.id);
                                }
                              });
                              c.commit(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Text(
                    'Quality Gate hinzufügen',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'z.B. QG1',
                    ),
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
                  c.qualityGates.add(QualityGate(name: nameC.text.trim()));
                  nameC.clear();
                });
                c.commit(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
          ],
        ),
      );
    },
  );
}
