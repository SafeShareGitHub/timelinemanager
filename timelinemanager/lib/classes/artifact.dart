import 'package:flutter/material.dart';

class ArtifactType {
  String key;
  int colorValue;
  ArtifactType(this.key, Color color) : colorValue = color.value;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {"key": key, "color": colorValue};
  static ArtifactType fromJson(Map<String, dynamic> j) =>
      ArtifactType(j['key'], Color(j['color']))..colorValue = j['color'];
}

class Artifact {
  final String id;
  String name;
  String type;
  String owner;
  String documentId;
  DateTime date;
  double y;
  String notes;
  List<String> inputs; // inbound selections
  List<String> outputs; // outbound selections
  List<String> bandIds; // phases
  List<String> eventIds; // milestones

  /// new fields
  bool klar;
  bool liegtVor;

  Artifact({
    String? id, // optional, wird generiert wenn null
    required this.name,
    required this.type,
    required this.owner,
    required this.documentId,
    required this.date,
    required this.y,
    this.notes = '',
    List<String>? inputs,
    List<String>? outputs,
    List<String>? bandIds,
    List<String>? eventIds,
    this.klar = false,
    this.liegtVor = false,
  }) : id = id ?? UniqueKey().toString(),
       inputs = inputs ?? [],
       outputs = outputs ?? [],
       bandIds = bandIds ?? [],
       eventIds = eventIds ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'owner': owner,
    'documentId': documentId,
    'date': date.toIso8601String(),
    'y': y,
    'notes': notes,
    'inputs': inputs,
    'outputs': outputs,
    'bandIds': bandIds,
    'eventIds': eventIds,
    'klar': klar,
    'liegtVor': liegtVor,
  };

  static Artifact fromJson(Map<String, dynamic> j) => Artifact(
    id: j['id'],
    name: j['name'],
    type: j['type'],
    owner: j['owner'] ?? '',
    documentId: j['documentId'] ?? '',
    date: DateTime.parse(j['date']),
    y: (j['y'] ?? 120).toDouble(),
    notes: j['notes'] ?? '',
    inputs: (j['inputs'] as List?)?.map((e) => e.toString()).toList() ?? [],
    outputs: (j['outputs'] as List?)?.map((e) => e.toString()).toList() ?? [],
    bandIds: (j['bandIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    eventIds: (j['eventIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    klar: j['klar'] ?? false,
    liegtVor: j['liegtVor'] ?? false,
  );
}
