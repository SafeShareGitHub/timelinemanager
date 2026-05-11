import 'package:flutter/material.dart';
import 'package:timelinemanager/platform/session_store.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

/// Shows a dialog letting the user replace the current session with either
/// a saved snapshot or a pasted session-JSON blob.
Future<void> showSessionRestoreDialog(
  BuildContext context,
  TimelineController c,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _SessionRestoreDialog(controller: c),
  );
}

class _SessionRestoreDialog extends StatefulWidget {
  final TimelineController controller;
  const _SessionRestoreDialog({required this.controller});

  @override
  State<_SessionRestoreDialog> createState() => _SessionRestoreDialogState();
}

class _SessionRestoreDialogState extends State<_SessionRestoreDialog> {
  late final List<SnapshotEntry> _snapshots = listSnapshots();
  final TextEditingController _pasteController = TextEditingController();
  SnapshotEntry? _selected;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  void _restoreFromSnapshot(SnapshotEntry entry) {
    final data = readSessionAtPathSync(entry.path);
    if (data == null) {
      _showError('Snapshot konnte nicht gelesen werden.');
      return;
    }
    _confirmAndApply(data, source: entry.name);
  }

  void _restoreFromPaste() {
    final data = parseSessionFromJson(_pasteController.text);
    if (data == null) {
      _showError('Ungültiges Session-JSON.');
      return;
    }
    _confirmAndApply(data, source: 'eingefügtem JSON');
  }

  Future<void> _confirmAndApply(
    SessionData data, {
    required String source,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sitzung ersetzen?'),
        content: Text(
          'Aktuelle Projekte werden durch ${data.projects.length} '
          'Projekt(e) aus $source ersetzt.\n\n'
          'Tipp: Erstelle vorher einen Snapshot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ersetzen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.controller.restoreFromSession(data);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sitzung wiederhergestellt aus $source.')),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sitzung wiederherstellen'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Snapshots (${_snapshots.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _snapshots.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Noch keine Snapshots vorhanden.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _snapshots.length,
                      itemBuilder: (ctx, i) {
                        final s = _snapshots[i];
                        final selected = identical(_selected, s);
                        return ListTile(
                          dense: true,
                          selected: selected,
                          onTap: () => setState(() => _selected = s),
                          leading: const Icon(Icons.history),
                          title: Text(s.name),
                          subtitle: Text(
                            '${s.projectCount} Projekt(e) · '
                            '${_formatDate(s.modified)}',
                          ),
                          trailing: Radio<SnapshotEntry>(
                            value: s,
                            groupValue: _selected,
                            onChanged: (v) => setState(() => _selected = v),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 24),
            Text(
              'Oder Session-JSON einfügen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _pasteController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{"version":1,"projects":[…]}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
        TextButton(
          onPressed: _pasteController.text.trim().isEmpty
              ? null
              : _restoreFromPaste,
          child: const Text('JSON laden'),
        ),
        FilledButton(
          onPressed:
              _selected == null ? null : () => _restoreFromSnapshot(_selected!),
          child: const Text('Snapshot laden'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
