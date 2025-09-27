import 'package:flutter/material.dart';

class TimeEvent {
  String id;
  String label;
  int colorValue;
  String type;
  DateTime date;
  TimeEvent({
    required this.id,
    required this.label,
    required Color color,
    required this.type,
    required this.date,
  }) : colorValue = color.value;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'color': colorValue,
    'type': type,
    'date': date.toIso8601String(),
  };
  static TimeEvent fromJson(Map<String, dynamic> j) => TimeEvent(
    id: j['id'],
    label: j['label'],
    color: Color(j['color']),
    type: j['type'] ?? '',
    date: DateTime.parse(j['date']),
  );
}
