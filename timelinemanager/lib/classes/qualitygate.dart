/// A named quality gate. Artifacts reference gates by [id]; the [name]
/// (e.g. "QG1") is what the search box matches against.
class QualityGate {
  final String id;
  String name;

  QualityGate({String? id, required this.name})
    : id = id ?? 'QG${DateTime.now().microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static QualityGate fromJson(Map<String, dynamic> j) =>
      QualityGate(id: j['id']?.toString(), name: (j['name'] ?? '').toString());
}
