/// A single to-do. Used both inside artifacts (`Artifact.todos`) and as a
/// stand-alone project-level entry (`TimelineController.globalTodos`).
///
/// [createdAt] is stamped automatically on creation. [assignee] holds a
/// person name from the org chart (free text, may be empty). [deadline] is
/// optional.
class TodoItem {
  final String id;
  String text;
  DateTime createdAt;
  String assignee;
  DateTime? deadline;
  bool done;

  TodoItem({
    String? id,
    this.text = '',
    DateTime? createdAt,
    this.assignee = '',
    this.deadline,
    this.done = false,
  }) : id = id ?? 'TD${DateTime.now().microsecondsSinceEpoch}',
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'assignee': assignee,
    'deadline': deadline?.toIso8601String(),
    'done': done,
  };

  static TodoItem fromJson(Map<String, dynamic> j) {
    final rawDeadline = (j['deadline'] ?? '').toString();
    return TodoItem(
      id: j['id']?.toString(),
      text: (j['text'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      assignee: (j['assignee'] ?? '').toString(),
      deadline: rawDeadline.isEmpty ? null : DateTime.tryParse(rawDeadline),
      done: j['done'] == true,
    );
  }

  TodoItem copy() => TodoItem(
    id: id,
    text: text,
    createdAt: createdAt,
    assignee: assignee,
    deadline: deadline,
    done: done,
  );
}
