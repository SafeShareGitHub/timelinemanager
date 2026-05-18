import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/classes/todo.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/widgets/todo_list_editor.dart';

/// Collapsible side panel listing every to-do in the project: the
/// project-level [TimelineController.globalTodos] plus the to-dos of each
/// artifact. Collapsed it is a thin rail; expanded it is a 340 px column.
class GlobalTodoPanel extends StatefulWidget {
  final TimelineController controller;

  const GlobalTodoPanel({super.key, required this.controller});

  @override
  State<GlobalTodoPanel> createState() => _GlobalTodoPanelState();
}

class _GlobalTodoPanelState extends State<GlobalTodoPanel> {
  bool _open = false;

  TimelineController get c => widget.controller;

  Future<void> _addGlobalTodo() async {
    final t = await showTodoEditorDialog(context, personNames: c.personNames);
    if (t != null) c.commit(() => c.globalTodos.add(t));
  }

  Future<void> _editTodo(TodoItem todo, {Artifact? artifact}) async {
    final edited = await showTodoEditorDialog(
      context,
      initial: todo,
      personNames: c.personNames,
    );
    if (edited == null) return;
    c.commit(() {
      final list = artifact?.todos ?? c.globalTodos;
      final i = list.indexWhere((t) => t.id == todo.id);
      if (i >= 0) list[i] = edited;
    });
  }

  void _deleteTodo(TodoItem todo, {Artifact? artifact}) {
    c.commit(() => (artifact?.todos ?? c.globalTodos).removeWhere(
          (t) => t.id == todo.id,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _open ? 340 : 44,
      child: Material(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        child: _open ? _buildExpanded(context) : _buildCollapsed(context),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        IconButton(
          tooltip: 'Globale To-dos öffnen',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _open = true),
        ),
        const Icon(Icons.checklist),
        const SizedBox(height: 8),
        const RotatedBox(
          quarterTurns: 1,
          child: Text(
            'TO-DOS',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final artifactsWithTodos =
        c.artifacts.where((a) => a.todos.isNotEmpty).toList();
    final isEmpty = c.globalTodos.isEmpty && artifactsWithTodos.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Einklappen',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _open = false),
              ),
              const Expanded(
                child: Text(
                  'Alle To-dos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Globales To-do hinzufügen',
                icon: const Icon(Icons.add),
                onPressed: _addGlobalTodo,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Keine To-dos.\nMit + ein globales To-do anlegen '
                      'oder in einem Artefakt.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (c.globalTodos.isNotEmpty) ...[
                      _sectionHeader(context, 'Global'),
                      for (final t in c.globalTodos) _todoTile(context, t),
                    ],
                    for (final a in artifactsWithTodos) ...[
                      _sectionHeader(
                        context,
                        a.name,
                        onTap: () => c.setFocus(a.id),
                      ),
                      for (final t in a.todos)
                        _todoTile(context, t, artifact: a),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String label, {
    VoidCallback? onTap,
  }) {
    final text = Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Theme.of(context).colorScheme.primary,
      ),
      overflow: TextOverflow.ellipsis,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      child: onTap == null
          ? text
          : InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, size: 13),
                  const SizedBox(width: 4),
                  Expanded(child: text),
                ],
              ),
            ),
    );
  }

  Widget _todoTile(BuildContext context, TodoItem t, {Artifact? artifact}) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Checkbox(
        value: t.done,
        onChanged: (v) => c.commit(() => t.done = v ?? false),
      ),
      title: Text(
        t.text,
        style: TextStyle(
          decoration: t.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        todoMetaLine(t),
        style: TextStyle(
          fontSize: 10,
          color: todoIsOverdue(t) ? Colors.red : null,
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Aktionen',
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (v) {
          switch (v) {
            case 'edit':
              _editTodo(t, artifact: artifact);
              break;
            case 'delete':
              _deleteTodo(t, artifact: artifact);
              break;
            case 'goto':
              if (artifact != null) c.setFocus(artifact.id);
              break;
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
          const PopupMenuItem(value: 'delete', child: Text('Löschen')),
          if (artifact != null)
            const PopupMenuItem(value: 'goto', child: Text('Zum Artefakt')),
        ],
      ),
    );
  }
}
