import 'package:flutter/material.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

/// Builds the editable list of linked-document paths used by the new- and
/// edit-artifact dialogs. The caller owns the [controllers] list (so it can
/// read the values at save time) and passes its dialog's [setLocal].
class LinkedFilesField extends StatelessWidget {
  final List<TextEditingController> controllers;
  final StateSetter setLocal;
  final TimelineController c;
  final bool showOpenButtons;

  const LinkedFilesField({
    super.key,
    required this.controllers,
    required this.setLocal,
    required this.c,
    this.showOpenButtons = true,
  });

  String _hint() => c.basePath.isEmpty
      ? r'C:\SmarTeam\Work\BU_6705556.docx'
      : 'BU_6705556.docx  (relativ zu ${c.basePath})';

  Future<void> _open(BuildContext context, String value) async {
    final result = await c.openArtifactFile(value);
    if (!context.mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Öffnen fehlgeschlagen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Verknüpfte Dateien',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Datei hinzufügen',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  setLocal(() => controllers.add(TextEditingController())),
            ),
          ],
        ),
        if (controllers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Keine — auf + klicken zum Hinzufügen.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ),
        for (var i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _hint(),
                    ),
                  ),
                ),
                if (showOpenButtons)
                  IconButton(
                    tooltip: 'Öffnen',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () {
                      final v = controllers[i].text.trim();
                      if (v.isEmpty) return;
                      _open(context, v);
                    },
                  ),
                IconButton(
                  tooltip: 'Entfernen',
                  icon: const Icon(Icons.close),
                  onPressed: () => setLocal(() => controllers.removeAt(i)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Builds editing controllers from saved paths.
List<TextEditingController> makeLinkedFileControllers(List<String> files) =>
    files.map((f) => TextEditingController(text: f)).toList();

/// Reads the controllers back into a clean list: quotes stripped, blanks
/// dropped.
List<String> readLinkedFileControllers(List<TextEditingController> cs) => cs
    .map((c) => TimelineController.stripPathQuotes(c.text))
    .where((s) => s.isNotEmpty)
    .toList();
