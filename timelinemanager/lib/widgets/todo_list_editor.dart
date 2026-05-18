import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/todo.dart';
import 'package:timelinemanager/utils/date_utils.dart';
import 'package:timelinemanager/widgets/person_autocomplete_field.dart';

/// One-line summary of a to-do's metadata (assignee · deadline · created).
String todoMetaLine(TodoItem t) {
  final parts = <String>[];
  if (t.assignee.trim().isNotEmpty) parts.add('👤 ${t.assignee.trim()}');
  if (t.deadline != null) parts.add('⏰ ${fmtDate(t.deadline!)}');
  parts.add('angelegt ${fmtDate(t.createdAt)}');
  return parts.join('  ·  ');
}

/// True when [t] has a deadline that is today or already past and isn't done.
bool todoIsOverdue(TodoItem t) {
  if (t.done || t.deadline == null) return false;
  final today = DateTime.now();
  final d = t.deadline!;
  return !DateTime(d.year, d.month, d.day)
      .isAfter(DateTime(today.year, today.month, today.day));
}

/// Modal to create or edit a single [TodoItem]. Returns the edited item
/// (a fresh one when [initial] is null) or null on cancel. The created
/// date is stamped automatically and never editable.
Future<TodoItem?> showTodoEditorDialog(
  BuildContext context, {
  TodoItem? initial,
  required List<String> personNames,
}) {
  final textC = TextEditingController(text: initial?.text ?? '');
  final assigneeC = TextEditingController(text: initial?.assignee ?? '');
  DateTime? deadline = initial?.deadline;

  return showDialog<TodoItem>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(initial == null ? 'Neues To-do' : 'To-do bearbeiten'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textC,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Aufgabe'),
              ),
              const SizedBox(height: 10),
              PersonAutocompleteField(
                controller: assigneeC,
                options: personNames,
                decoration: const InputDecoration(
                  labelText: 'Zuständige Person',
                  hintText: 'Name aus dem Organigramm',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Deadline:'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: deadline ?? DateTime.now(),
                      );
                      if (p != null) setLocal(() => deadline = p);
                    },
                    child: Text(
                      deadline == null ? '— keine —' : fmtDate(deadline!),
                    ),
                  ),
                  if (deadline != null)
                    IconButton(
                      tooltip: 'Deadline entfernen',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setLocal(() => deadline = null),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final text = textC.text.trim();
              if (text.isEmpty) return;
              final result = initial?.copy() ?? TodoItem();
              result.text = text;
              result.assignee = assigneeC.text.trim();
              result.deadline = deadline;
              Navigator.pop(ctx, result);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}

/// Editable list of to-dos used inside the new-/edit-artifact dialogs.
/// The caller owns [todos] (so it can persist it on save) and passes its
/// dialog's [setLocal] so edits redraw immediately.
class TodoListEditor extends StatelessWidget {
  final List<TodoItem> todos;
  final StateSetter setLocal;
  final List<String> personNames;

  const TodoListEditor({
    super.key,
    required this.todos,
    required this.setLocal,
    required this.personNames,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('To-dos', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: 'To-do hinzufügen',
              icon: const Icon(Icons.add),
              onPressed: () async {
                final t = await showTodoEditorDialog(
                  context,
                  personNames: personNames,
                );
                if (t != null) setLocal(() => todos.add(t));
              },
            ),
          ],
        ),
        if (todos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Keine — auf + klicken zum Hinzufügen.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ),
        for (var i = 0; i < todos.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 4, right: 4),
              leading: Checkbox(
                value: todos[i].done,
                onChanged: (v) =>
                    setLocal(() => todos[i].done = v ?? false),
              ),
              title: Text(
                todos[i].text,
                style: TextStyle(
                  decoration: todos[i].done
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              subtitle: Text(
                todoMetaLine(todos[i]),
                style: TextStyle(
                  fontSize: 11,
                  color: todoIsOverdue(todos[i]) ? Colors.red : null,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Bearbeiten',
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () async {
                      final edited = await showTodoEditorDialog(
                        context,
                        initial: todos[i],
                        personNames: personNames,
                      );
                      if (edited != null) {
                        setLocal(() => todos[i] = edited);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Löschen',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => setLocal(() => todos.removeAt(i)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
