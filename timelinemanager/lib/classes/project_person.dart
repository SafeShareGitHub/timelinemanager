class ProjectPerson {
  final String id;
  String name;
  String role;

  ProjectPerson({String? id, required this.name, this.role = ''})
      : id = id ?? 'P${DateTime.now().microsecondsSinceEpoch}';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};

  static ProjectPerson fromJson(Map<String, dynamic> j) => ProjectPerson(
    id: j['id'],
    name: j['name'] ?? '',
    role: j['role'] ?? '',
  );
}
