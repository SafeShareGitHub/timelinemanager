String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<String> splitList(String s) =>
    s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
