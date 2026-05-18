/// One entry in the org chart ("Organigramm"). Both [organisation] and
/// [role] are free text and intentionally allowed to repeat across people —
/// they group several persons together. [name] is what artifact fields
/// auto-suggest against.
class Person {
  String organisation;
  String name;
  String role;

  Person({this.organisation = '', required this.name, this.role = ''});

  Map<String, dynamic> toJson() => {
    'organisation': organisation,
    'name': name,
    'role': role,
  };

  static Person fromJson(Map<String, dynamic> j) => Person(
    organisation: (j['organisation'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    role: (j['role'] ?? '').toString(),
  );
}
