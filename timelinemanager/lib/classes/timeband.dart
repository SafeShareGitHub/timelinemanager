import 'package:flutter/material.dart';

class TimeBand {
  // phases (bottom)
  String id;
  String label;
  int colorValue;
  String type;
  DateTime start;
  DateTime end;
  TimeBand({
    required this.id,
    required this.label,
    required Color color,
    required this.type,
    required this.start,
    required this.end,
  }) : colorValue = color.value;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'color': colorValue,
    'type': type,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };
  static TimeBand fromJson(Map<String, dynamic> j) => TimeBand(
    id: j['id'],
    label: j['label'],
    color: Color(j['color']),
    type: j['type'] ?? '',
    start: DateTime.parse(j['start']),
    end: DateTime.parse(j['end']),
  );
}
