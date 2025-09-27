class Link {
  String id;
  String fromId; // Artifact.id or Link.id
  String toId; // Artifact.id or Link.id
  String label;
  Link({
    required this.id,
    required this.fromId,
    required this.toId,
    this.label = '',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'fromId': fromId,
    'toId': toId,
    'label': label,
  };
  static Link fromJson(Map<String, dynamic> j) => Link(
    id: j['id'],
    fromId: j['fromId'],
    toId: j['toId'],
    label: j['label'] ?? '',
  );
}
