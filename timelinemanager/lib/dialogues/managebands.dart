import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/timeband.dart';
import 'package:timelinemanager/dialogues/pickcolor.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/utils/date_utils.dart';

Future<void> showManageBandsDialog(
  BuildContext context,
  TimelineController c,
) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      final labelC = TextEditingController();
      final typeC = TextEditingController();
      DateTime start = c.origin;
      DateTime end = c.endDate;
      Color chosen = Colors.teal;
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Zeit-Bänder verwalten'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...c.bands.map(
                    (b) => ListTile(
                      leading: CircleAvatar(backgroundColor: b.color),
                      title: Text(
                        '${b.label} (${fmtDate(b.start)} → ${fmtDate(b.end)})',
                      ),
                      subtitle: Text(b.type.isEmpty ? '—' : b.type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.color_lens_outlined),
                            onPressed: () async {
                              final picked = await showColorPickerDialog(
                                ctx,
                                initial: b.color,
                              );
                              if (picked != null) {
                                setLocal(() => b.colorValue = picked.value);
                                c.commit(() {});
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final lc = TextEditingController(text: b.label);
                              final tc = TextEditingController(text: b.type);
                              DateTime s = b.start;
                              DateTime e = b.end;
                              await showDialog(
                                context: ctx,
                                builder: (c2) => StatefulBuilder(
                                  builder: (c2, setInner) => AlertDialog(
                                    title: const Text('Band bearbeiten'),
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
                                            const Text('Start:'),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () async {
                                                final p = await showDatePicker(
                                                  context: ctx,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                  initialDate: s,
                                                );
                                                if (p != null) {
                                                  setInner(() => s = p);
                                                }
                                              },
                                              child: Text(fmtDate(s)),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Ende:'),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () async {
                                                final p = await showDatePicker(
                                                  context: ctx,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                  initialDate: e,
                                                );
                                                if (p != null) {
                                                  setInner(() => e = p);
                                                }
                                              },
                                              child: Text(fmtDate(e)),
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
                                            b.label = lc.text.trim();
                                            b.type = tc.text.trim();
                                            b.start = s;
                                            b.end = e;
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
                              setLocal(() => c.bands.remove(b));
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
                      'Neues Band hinzufügen',
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
                      const Text('Start:'),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: start,
                          );
                          if (p != null) setLocal(() => start = p);
                        },
                        child: Text(fmtDate(start)),
                      ),
                      const SizedBox(width: 12),
                      const Text('Ende:'),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: end,
                          );
                          if (p != null) setLocal(() => end = p);
                        },
                        child: Text(fmtDate(end)),
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
                  c.bands.add(
                    TimeBand(
                      id: 'B${DateTime.now().microsecondsSinceEpoch}',
                      label: labelC.text.trim(),
                      color: chosen,
                      type: typeC.text.trim(),
                      start: start,
                      end: end,
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
