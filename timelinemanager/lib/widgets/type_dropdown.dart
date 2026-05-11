import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';

class TypeDropdown extends StatelessWidget {
  final List<ArtifactType> types;
  final String value;
  final ValueChanged<String?> onChanged;

  const TypeDropdown({
    super.key,
    required this.types,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    decoration: const InputDecoration(labelText: 'Typ'),
    items: [
      for (final t in types)
        DropdownMenuItem(value: t.key, child: Text(t.key)),
    ],
    onChanged: onChanged,
  );
}
