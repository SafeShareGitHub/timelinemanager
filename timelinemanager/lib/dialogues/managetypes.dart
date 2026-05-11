import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/dialogues/pickcolor.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

Future<void> showManageTypesDialog(
  BuildContext context,
  TimelineController c,
) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      final nameC = TextEditingController();
      Color chosen =
          Colors.primaries[(c.artifactTypes.length) % Colors.primaries.length];
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Artifact Types verwalten'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...c.artifactTypes.map(
                  (t) => ListTile(
                    leading: CircleAvatar(backgroundColor: t.color),
                    title: Text(t.key),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Farbe ändern',
                          icon: const Icon(Icons.color_lens_outlined),
                          onPressed: () async {
                            final picked = await showColorPickerDialog(
                              ctx,
                              initial: t.color,
                            );
                            if (picked != null) {
                              setLocal(() {
                                t.colorValue = picked.value;
                              });
                              c.commit(() {});
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Umbenennen',
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final nc = TextEditingController(text: t.key);
                            await showDialog(
                              context: ctx,
                              builder: (c2) => AlertDialog(
                                title: const Text('Typ umbenennen'),
                                content: TextField(
                                  controller: nc,
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
                                      setLocal(() => t.key = nc.text.trim());
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
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setLocal(() => c.artifactTypes.remove(t));
                            c.commit(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Neuen Typ hinzufügen',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in Colors.primaries)
                      GestureDetector(
                        onTap: () => setLocal(() => chosen = color),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: color,
                          child: chosen == color
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
            ),
            FilledButton(
              onPressed: () {
                if (nameC.text.trim().isEmpty) return;
                setLocal(
                  () => c.artifactTypes.add(
                    ArtifactType(nameC.text.trim(), chosen),
                  ),
                );
                c.commit(() {});
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      );
    },
  );
}
