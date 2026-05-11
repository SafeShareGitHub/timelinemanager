import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/timeEvent.dart';
import 'package:timelinemanager/dialogues/pickcolor.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/utils/date_utils.dart';

Future<void> showManageEventsDialog(
  BuildContext context,
  TimelineController c,
) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      final labelC = TextEditingController();
      final typeC = TextEditingController();
      DateTime date = DateTime.now();
      Color chosen = Colors.pink;
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Events verwalten'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...c.events.map(
                    (e) => ListTile(
                      leading: CircleAvatar(backgroundColor: e.color),
                      title: Text('${e.label} (${fmtDate(e.date)})'),
                      subtitle: Text(e.type.isEmpty ? '—' : e.type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.color_lens_outlined),
                            onPressed: () async {
                              final picked = await showColorPickerDialog(
                                ctx,
                                initial: e.color,
                              );
                              if (picked != null) {
                                setLocal(() => e.colorValue = picked.value);
                                c.commit(() {});
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final lc = TextEditingController(text: e.label);
                              final tc = TextEditingController(text: e.type);
                              DateTime d = e.date;
                              await showDialog(
                                context: ctx,
                                builder: (c2) => StatefulBuilder(
                                  builder: (c2, setInner) => AlertDialog(
                                    title: const Text('Event bearbeiten'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: lc,
                                          decoration: const InputDecoration(
                                            labelText: 'Label',
                                          ),
                                        ),
                                        TextField(
                                          controller: tc,
                                          decoration: const InputDecoration(
                                            labelText: 'Typ',
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Text('Datum:'),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () async {
                                                final p = await showDatePicker(
                                                  context: ctx,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                  initialDate: d,
                                                );
                                                if (p != null) {
                                                  setInner(() => d = p);
                                                }
                                              },
                                              child: Text(fmtDate(d)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c2),
                                        child: const Text('Abbrechen'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          setLocal(() {
                                            e.label = lc.text.trim();
                                            e.type = tc.text.trim();
                                            e.date = d;
                                          });
                                          c.commit(() {});
                                          Navigator.pop(c2);
                                        },
                                        child: const Text('Speichern'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setLocal(() {
                                c.events.remove(e);
                                for (final a in c.artifacts) {
                                  a.eventIds.remove(e.id);
                                }
                              });
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
                      'Neues Event hinzufügen',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelC,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  TextField(
                    controller: typeC,
                    decoration: const InputDecoration(
                      labelText: 'Typ (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Datum:'),
                      const SizedBox(width: 8),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
            ),
            FilledButton(
              onPressed: () {
                if (labelC.text.trim().isEmpty) return;
                setLocal(() {
                  c.events.add(
                    TimeEvent(
                      id: 'E${DateTime.now().microsecondsSinceEpoch}',
                      label: labelC.text.trim(),
                      type: typeC.text.trim(),
                      color: chosen,
                      date: date,
                    ),
                  );
                });
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
