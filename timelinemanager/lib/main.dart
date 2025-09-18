// Flutter Timeline Traceability Tool — MAX POTENCY v2.5 (DartPad-ready, single file)
// ---------------------------------------------------------------------------
// v2.5 (new in this reply):
// ✔ Fokus/Highlight: Artefakt lange drücken → zeigt nur verkettete Artefakte/Links
//    (umschaltbar: Dimmen vs. Ausblenden). Toolbar: Fokus löschen + Dim/Ausblenden.
// ✔ Inputs/Outputs-Auswahl via Artefakt-Picker (statt Text) – Links werden automatisch
//    angelegt/entfernt. (Weiterhin in JSON in a.inputs/a.outputs gespiegelt.)
// ✔ Alles persistent via Undo/Redo + JSON.
//
// v2.4:
// ✔ Events (Milestones), Many-to-many Artifacts↔Phases/Events, Filter, Jahresfenster.
//
// v2.3:
// ✔ Phase bands: Overlap-Opacity + gestapelte "Movie Maker"-Lanes + Layout-Dialog.
//
// v2.2 recap: Undo/Redo, Zeitbereich, Bottom-Bands, Legend, Links, Smooth drag.
// No external packages. Works on DartPad Flutter.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const TraceabilityApp());

class TraceabilityApp extends StatelessWidget {
  const TraceabilityApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Timeline Traceability',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
        home: const TraceabilityHome(),
      );
}

// ----------------------------- Helpers & Extensions ------------------------
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
List<String> _splitList(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

// ----------------------------- Data Models ---------------------------------
class ArtifactType {
  String key;
  int colorValue;
  ArtifactType(this.key, Color color) : colorValue = color.value;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {"key": key, "color": colorValue};
  static ArtifactType fromJson(Map<String, dynamic> j) => ArtifactType(j['key'], Color(j['color']))..colorValue = j['color'];
}

class Artifact {
  String id;
  String name;
  String type;
  String owner;
  String documentId;
  DateTime date;
  double y;
  String notes;
  List<String> inputs;  // kept in sync with inbound selections
  List<String> outputs; // kept in sync with outbound selections
  // memberships
  List<String> bandIds;   // phases
  List<String> eventIds;  // milestones

  Artifact({
    required this.id,
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
  })  : inputs = inputs ?? [],
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
      );
}

class Link {
  String id;
  String fromId; // Artifact.id or Link.id
  String toId;   // Artifact.id or Link.id
  String label;
  Link({required this.id, required this.fromId, required this.toId, this.label = ''});
  Map<String, dynamic> toJson() => {'id': id, 'fromId': fromId, 'toId': toId, 'label': label};
  static Link fromJson(Map<String, dynamic> j) => Link(id: j['id'], fromId: j['fromId'], toId: j['toId'], label: j['label'] ?? '');
}

class TimeBand { // phases (bottom)
  String id;
  String label;
  int colorValue;
  String type;
  DateTime start;
  DateTime end;
  TimeBand({required this.id, required this.label, required Color color, required this.type, required this.start, required this.end}) : colorValue = color.value;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'color': colorValue, 'type': type, 'start': start.toIso8601String(), 'end': end.toIso8601String()};
  static TimeBand fromJson(Map<String, dynamic> j) => TimeBand(id: j['id'], label: j['label'], color: Color(j['color']), type: j['type'] ?? '', start: DateTime.parse(j['start']), end: DateTime.parse(j['end']));
}

// dated milestone pin
class TimeEvent {
  String id;
  String label;
  int colorValue;
  String type;
  DateTime date;
  TimeEvent({required this.id, required this.label, required Color color, required this.type, required this.date}) : colorValue = color.value;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'color': colorValue, 'type': type, 'date': date.toIso8601String()};
  static TimeEvent fromJson(Map<String, dynamic> j) => TimeEvent(id: j['id'], label: j['label'], color: Color(j['color']), type: j['type'] ?? '', date: DateTime.parse(j['date']));
}

// ------------------------------ Home ---------------------------------------
class TraceabilityHome extends StatefulWidget {
  const TraceabilityHome({super.key});
  @override
  State<TraceabilityHome> createState() => _TraceabilityHomeState();
}

enum FilterMode { ignore, showOnly, hideSelected }

class _TraceabilityHomeState extends State<TraceabilityHome> {
  // State
  final List<Artifact> artifacts = [];
  final List<Link> links = [];
  final List<ArtifactType> artifactTypes = [
    ArtifactType('Requirement', const Color(0xFF2563EB)),
    ArtifactType('Spec', const Color(0xFF7C3AED)),
    ArtifactType('Design', const Color(0xFF059669)),
    ArtifactType('Test', const Color(0xFFDC2626)),
    ArtifactType('Risk', const Color(0xFFEA580C)),
    ArtifactType('Doc', const Color(0xFF0EA5E9)),
  ];
  final List<TimeBand> bands = [];
  final List<TimeEvent> events = [];

  // Timeline config
  DateTime origin = DateTime.now().subtract(const Duration(days: 90));
  DateTime endDate = DateTime.now().add(const Duration(days: 30));
  double pxPerDay = 24; // zoom factor
  double canvasHeight = 760;

  // Band layout config
  bool bandStackMode = false;
  double bandOpacity = 0.6;
  double bandRowHeight = 22;
  double bandRowGap = 6;

  // Filters
  String? typeFilter;
  bool showOnlyUnlinked = false;
  String search = '';
  bool dimFiltered = false;

  // Filter by phases/events
  final Set<String> selectedBandIds = {};
  final Set<String> selectedEventIds = {};
  FilterMode filterMode = FilterMode.ignore;

  // Focus/Highlight
  String? focusArtifactId;
  bool focusDimOthers = true; // true = dimmen; false = ausblenden
  Set<String> _focusedArtifactIds = {};
  Set<String> _focusedLinkIds = {};

  // Undo/Redo stacks
  final List<String> _history = [];
  int _historyIndex = -1;

  // Link mode
  bool linkMode = false;
  String? pendingLinkFromId;

  // Drag helper
  final Map<String, Offset> _dragPosOverride = {};

  @override
  void initState() {
    super.initState();
    _seedDemo();
    _pushHistory();
  }

  void _seedDemo() {
    final now = DateTime.now();
    artifacts.addAll([
      Artifact(id: 'R-101', name: 'Door shall auto-lock', type: 'Requirement', owner: 'PM', documentId: 'REQ-101', date: now.subtract(const Duration(days: 80)), y: 120, inputs: ['SRD-1'], outputs: ['S-12']),
      Artifact(id: 'S-12', name: 'Locking Spec v1', type: 'Spec', owner: 'SE', documentId: 'SPEC-12', date: now.subtract(const Duration(days: 50)), y: 200, inputs: ['R-101'], outputs: ['D-5']),
      Artifact(id: 'D-5', name: 'Door Controller PCB', type: 'Design', owner: 'HW', documentId: 'DES-5', date: now.subtract(const Duration(days: 30)), y: 280, outputs: ['T-77']),
      Artifact(id: 'T-77', name: 'Locking integration test', type: 'Test', owner: 'QA', documentId: 'TEST-77', date: now.subtract(const Duration(days: 10)), y: 360),
      Artifact(id: 'RK-9', name: 'Hazard: unlock in motion', type: 'Risk', owner: 'RAMS', documentId: 'RISK-9', date: now.subtract(const Duration(days: 60)), y: 440),
    ]);
    links.addAll([
      Link(id: 'L1', fromId: 'R-101', toId: 'S-12', label: 'refines'),
      Link(id: 'L2', fromId: 'S-12', toId: 'D-5', label: 'implements'),
      Link(id: 'L3', fromId: 'D-5', toId: 'T-77', label: 'verifies'),
      Link(id: 'L4', fromId: 'RK-9', toId: 'S-12', label: 'mitigates in'),
    ]);
    // phases
    bands.addAll([
      TimeBand(id: 'B1', label: 'Phase A', color: const Color(0xFF0EA5E9), type: 'Phase', start: now.subtract(const Duration(days: 75)), end: now.subtract(const Duration(days: 40))),
      TimeBand(id: 'B2', label: 'Phase B', color: const Color(0xFF22C55E), type: 'Phase', start: now.subtract(const Duration(days: 55)), end: now.subtract(const Duration(days: 5))),
      TimeBand(id: 'B3', label: 'Phase C', color: const Color(0xFFF59E0B), type: 'Phase', start: now.subtract(const Duration(days: 35)), end: now.add(const Duration(days: 10))),
    ]);
    // events
    events.addAll([
      TimeEvent(id: 'E1', label: 'SRR', type: 'Review', color: const Color(0xFF9333EA), date: now.subtract(const Duration(days: 60))),
      TimeEvent(id: 'E2', label: 'PDR', type: 'Review', color: const Color(0xFFDB2777), date: now.subtract(const Duration(days: 35))),
      TimeEvent(id: 'E3', label: 'CDR', type: 'Review', color: const Color(0xFF0EA5E9), date: now.subtract(const Duration(days: 12))),
      TimeEvent(id: 'E4', label: 'TRR', type: 'Review', color: const Color(0xFF22C55E), date: now.add(const Duration(days: 7))),
    ]);
    origin = DateTime(now.year, now.month - 3, now.day);
    endDate = now.add(const Duration(days: 30));
  }

  // -------------------------- History (Undo/Redo) --------------------------
  String _serialize() => jsonEncode({
        'origin': origin.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'pxPerDay': pxPerDay,
        'types': artifactTypes.map((t) => t.toJson()).toList(),
        'artifacts': artifacts.map((a) => a.toJson()).toList(),
        'links': links.map((l) => l.toJson()).toList(),
        'bands': bands.map((b) => b.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'bandStackMode': bandStackMode,
        'bandOpacity': bandOpacity,
        'bandRowHeight': bandRowHeight,
        'bandRowGap': bandRowGap,
        'selectedBandIds': selectedBandIds.toList(),
        'selectedEventIds': selectedEventIds.toList(),
        'filterMode': filterMode.index,
        'typeFilter': typeFilter,
        'showOnlyUnlinked': showOnlyUnlinked,
        'search': search,
        'dimFiltered': dimFiltered,
        'focusArtifactId': focusArtifactId,
        'focusDimOthers': focusDimOthers,
      });
  void _restore(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    origin = DateTime.parse(map['origin']);
    endDate = DateTime.parse(map['endDate']);
    pxPerDay = (map['pxPerDay'] as num).toDouble();
    artifactTypes..clear()..addAll(((map['types'] as List?) ?? []).map((e) => ArtifactType.fromJson(Map<String, dynamic>.from(e))));
    artifacts..clear()..addAll(((map['artifacts'] as List?) ?? []).map((e) => Artifact.fromJson(Map<String, dynamic>.from(e))));
    links..clear()..addAll(((map['links'] as List?) ?? []).map((e) => Link.fromJson(Map<String, dynamic>.from(e))));
    bands..clear()..addAll(((map['bands'] as List?) ?? []).map((e) => TimeBand.fromJson(Map<String, dynamic>.from(e))));
    events..clear()..addAll(((map['events'] as List?) ?? []).map((e) => TimeEvent.fromJson(Map<String, dynamic>.from(e))));
    bandStackMode = map['bandStackMode'] ?? false;
    bandOpacity = (map['bandOpacity'] ?? 0.6).toDouble();
    bandRowHeight = (map['bandRowHeight'] ?? 22.0).toDouble();
    bandRowGap = (map['bandRowGap'] ?? 6.0).toDouble();
    selectedBandIds
      ..clear()
      ..addAll(((map['selectedBandIds'] as List?) ?? []).map((e) => e.toString()));
    selectedEventIds
      ..clear()
      ..addAll(((map['selectedEventIds'] as List?) ?? []).map((e) => e.toString()));
    filterMode = FilterMode.values[(map['filterMode'] ?? 0).toInt()];
    typeFilter = map['typeFilter'];
    showOnlyUnlinked = map['showOnlyUnlinked'] ?? false;
    search = map['search'] ?? '';
    dimFiltered = map['dimFiltered'] ?? false;

    focusArtifactId = map['focusArtifactId'];
    focusDimOthers = map['focusDimOthers'] ?? true;
    if (focusArtifactId != null) {
      final res = _computeConnected(focusArtifactId!);
      _focusedArtifactIds = res.$1;
      _focusedLinkIds = res.$2;
    } else {
      _focusedArtifactIds.clear();
      _focusedLinkIds.clear();
    }
  }
  void _pushHistory() {
    final snap = _serialize();
    if (_historyIndex >= 0 && _historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(snap);
    _historyIndex = _history.length - 1;
  }
  void _undo() { if (_historyIndex <= 0) return; _historyIndex--; setState(() => _restore(_history[_historyIndex])); }
  void _redo() { if (_historyIndex >= _history.length - 1) return; _historyIndex++; setState(() => _restore(_history[_historyIndex])); }

  // -------------------------- Helpers --------------------------------------
  ArtifactType typeByKey(String key) => artifactTypes.firstWhere((t) => t.key == key, orElse: () => ArtifactType('Other', const Color(0xFF64748B)));
  double xForDate(DateTime d) => d.difference(origin).inDays * pxPerDay + 140;
  DateTime dateForX(double x) {
    final days = ((x - 140) / pxPerDay).round();
    return origin.add(Duration(days: days));
  }
  //double snapLane(double y) => (y / 80).round().clamp(1, (canvasHeight - 60) ~/ 80).toDouble() * 80;

  Offset? positionOfId(String id, {int depth = 0}) {
    final Artifact? a = artifacts.firstWhereOrNull((x) => x.id == id);
    if (a != null) {
      final override = _dragPosOverride[id];
      if (override != null) return override;
      return Offset(xForDate(a.date), a.y);
    }
    final Link? l = links.firstWhereOrNull((x) => x.id == id);
    if (l != null && depth < 2) {
      final p1 = positionOfId(l.fromId, depth: depth + 1);
      final p2 = positionOfId(l.toId, depth: depth + 1);
      if (p1 == null || p2 == null) return null;
      return Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    }
    return null;
  }

  // focus helpers
  void _setFocus(String? id) {
    setState(() {
      focusArtifactId = id;
      if (id == null) {
        _focusedArtifactIds.clear();
        _focusedLinkIds.clear();
      } else {
        final res = _computeConnected(id);
        _focusedArtifactIds = res.$1;
        _focusedLinkIds = res.$2;
      }
    });
    _pushHistory();
  }

  /// BFS über Links beidseitig, liefert verbundene Artefakt- und Link-IDs
  (Set<String>, Set<String>) _computeConnected(String startId) {
    final artSet = <String>{startId};
    final linkSet = <String>{};
    final q = <String>[startId];

    final byFrom = <String, List<Link>>{};
    final byTo = <String, List<Link>>{};
    for (final l in links) {
      (byFrom[l.fromId] ??= []).add(l);
      (byTo[l.toId] ??= []).add(l);
    }

    while (q.isNotEmpty) {
      final cur = q.removeAt(0);
      // Ausgehende
      for (final l in byFrom[cur] ?? const []) {
        linkSet.add(l.id);
        if (artSet.add(l.toId)) q.add(l.toId);
      }
      // Eingehende
      for (final l in byTo[cur] ?? const []) {
        linkSet.add(l.id);
        if (artSet.add(l.fromId)) q.add(l.fromId);
      }
    }
    return (artSet, linkSet);
  }

  // IO helpers (links)
  List<String> _inboundOf(String id) =>
      links.where((l) => l.toId == id && artifacts.any((a) => a.id == l.fromId)).map((l) => l.fromId).toList();
  List<String> _outboundOf(String id) =>
      links.where((l) => l.fromId == id && artifacts.any((a) => a.id == l.toId)).map((l) => l.toId).toList();

  void _applyIOSelections(Artifact a, Set<String> inbound, Set<String> outbound) {
    // Remove obsolete inbound
    for (final l in links.where((l) => l.toId == a.id && !inbound.contains(l.fromId)).toList()) {
      links.remove(l);
    }
    // Remove obsolete outbound
    for (final l in links.where((l) => l.fromId == a.id && !outbound.contains(l.toId)).toList()) {
      links.remove(l);
    }
    // Add new inbound
    for (final from in inbound) {
      if (!links.any((l) => l.fromId == from && l.toId == a.id)) {
        links.add(Link(id: 'L${DateTime.now().microsecondsSinceEpoch}${from.hashCode}', fromId: from, toId: a.id));
      }
    }
    // Add new outbound
    for (final to in outbound) {
      if (!links.any((l) => l.fromId == a.id && l.toId == to)) {
        links.add(Link(id: 'L${DateTime.now().microsecondsSinceEpoch}${to.hashCode}', fromId: a.id, toId: to));
      }
    }
    // Mirror to text fields for persistence/interop
    a.inputs = inbound.toList();
    a.outputs = outbound.toList();
  }

  bool _passesMembershipFilters(Artifact a) {
    if (filterMode == FilterMode.ignore) return true;
    final inBands = a.bandIds.any(selectedBandIds.contains);
    final inEvents = a.eventIds.any(selectedEventIds.contains);
    final isSelected = (selectedBandIds.isNotEmpty && inBands) || (selectedEventIds.isNotEmpty && inEvents);
    if (filterMode == FilterMode.showOnly) {
      final hasAnyCriterion = selectedBandIds.isNotEmpty || selectedEventIds.isNotEmpty;
      return !hasAnyCriterion || isSelected;
    } else if (filterMode == FilterMode.hideSelected) {
      return !isSelected;
    }
    return true;
  }

  bool visibleArtifact(Artifact a) {
    final typeOk = typeFilter == null || a.type == typeFilter;
    final text = '${a.id} ${a.name} ${a.owner} ${a.documentId}'.toLowerCase();
    final searchOk = search.isEmpty || text.contains(search.toLowerCase());
    final unlinkedOk = !showOnlyUnlinked || !links.any((l) => l.fromId == a.id || l.toId == a.id);
    final membershipOk = _passesMembershipFilters(a);
    final inYearWindow = !a.date.isBefore(origin) && !a.date.isAfter(endDate);

    if (focusArtifactId != null && !_focusedArtifactIds.contains(a.id)) {
      if (focusDimOthers) {
        // allowed, will be dimmed in UI
      } else {
        return false; // hide
      }
    }
    return typeOk && searchOk && unlinkedOk && membershipOk && inYearWindow;
  }

  bool visibleLink(Link l) {
    final pFrom = positionOfId(l.fromId);
    final pTo = positionOfId(l.toId);
    if (pFrom == null || pTo == null) return false;

    bool endpointVisible(String id) {
      final af = artifacts.firstWhereOrNull((a) => a.id == id);
      if (af != null) return visibleArtifact(af);
      final lk = links.firstWhereOrNull((x) => x.id == id);
      if (lk != null && l.id != lk.id) return visibleLink(lk);
      return false;
    }
    bool baseVisible = endpointVisible(l.fromId) && endpointVisible(l.toId);

    if (!baseVisible) return false;
    if (focusArtifactId != null && !_focusedLinkIds.contains(l.id)) {
      if (focusDimOthers) {
        return true; // will be dimmed
      } else {
        return false; // hide
      }
    }
    return true;
  }

  List<Artifact> get artifactsToDraw => dimFiltered ? artifacts : artifacts.where(visibleArtifact).toList();
  List<Link> get linksToDraw => dimFiltered ? links : links.where(visibleLink).toList();

  // -------------------------- UI Actions -----------------------------------
  void _toggleLinkMode() => setState(() { linkMode = !linkMode; if (!linkMode) pendingLinkFromId = null; });
  void _onStateChanged() { setState(() {}); _pushHistory(); }

  void _openBandLayoutDialog() async {
    bool stack = bandStackMode;
    double opacity = bandOpacity;
    double rowH = bandRowHeight;
    double rowG = bandRowGap;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Band-Layout'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(title: const Text('Gestapelt (statt Überlappen)'), value: stack, onChanged: (v) => setState(() { stack = v; })),
            if (!stack) ...[
              const SizedBox(height: 8),
              const Text('Deckkraft bei Überlappung'),
              Slider(min: 0.2, max: 1.0, divisions: 8, value: opacity, label: opacity.toStringAsFixed(2), onChanged: (v) => setState(() { opacity = v; })),
            ],
            if (stack) ...[
              const SizedBox(height: 8),
              const Text('Reihenhöhe'),
              Slider(min: 14, max: 36, divisions: 11, value: rowH, label: '${rowH.round()} px', onChanged: (v) => setState(() { rowH = v; })),
              const SizedBox(height: 8),
              const Text('Abstand zwischen Reihen'),
              Slider(min: 2, max: 16, divisions: 14, value: rowG, label: '${rowG.round()} px', onChanged: (v) => setState(() { rowG = v; })),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () { setState(() { bandStackMode = stack; bandOpacity = opacity; bandRowHeight = rowH; bandRowGap = rowG; }); Navigator.pop(ctx); _pushHistory(); }, child: const Text('Übernehmen')),
        ],
      ),
    );
  }

  void _openFilterDialog() async {
    final tempBands = {...selectedBandIds};
    final tempEvents = {...selectedEventIds};
    FilterMode tempMode = filterMode;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter (Phasen & Events)'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Modus'),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Ignorieren'), selected: tempMode == FilterMode.ignore, onSelected: (_) => setState(() => tempMode = FilterMode.ignore)),
                ChoiceChip(label: const Text('Nur ausgewählte zeigen'), selected: tempMode == FilterMode.showOnly, onSelected: (_) => setState(() => tempMode = FilterMode.showOnly)),
                ChoiceChip(label: const Text('Ausgewählte ausblenden'), selected: tempMode == FilterMode.hideSelected, onSelected: (_) => setState(() => tempMode = FilterMode.hideSelected)),
              ]),
              const Divider(height: 20),
              Text('Phasen (${bands.length})', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final b in bands)
                  FilterChip(
                    avatar: CircleAvatar(backgroundColor: b.color, radius: 8),
                    label: Text(b.label),
                    selected: tempBands.contains(b.id),
                    onSelected: (v) => setState(() { if (v) tempBands.add(b.id); else tempBands.remove(b.id); }),
                  )
              ]),
              const Divider(height: 20),
              Text('Events (${events.length})', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in events)
                  FilterChip(
                    avatar: CircleAvatar(backgroundColor: e.color, radius: 8),
                    label: Text(e.label),
                    selected: tempEvents.contains(e.id),
                    onSelected: (v) => setState(() { if (v) tempEvents.add(e.id); else tempEvents.remove(e.id); }),
                  )
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')),
          FilledButton(onPressed: () { setState(() { selectedBandIds..clear()..addAll(tempBands); selectedEventIds..clear()..addAll(tempEvents); filterMode = tempMode; }); Navigator.pop(ctx); _pushHistory(); }, child: const Text('Anwenden')),
        ],
      ),
    );
  }

  void _openYearFilterDialog() async {
    int sYear = origin.year;
    int eYear = endDate.year;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jahresfilter'),
        content: SizedBox(
          width: 420,
          child: Row(children: [
            Expanded(child: _yearField('Startjahr', sYear, (v) { final n = int.tryParse(v); if (n != null) sYear = n; })),
            const SizedBox(width: 12),
            Expanded(child: _yearField('Endjahr', eYear, (v) { final n = int.tryParse(v); if (n != null) eYear = n; })),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () { if (eYear < sYear) eYear = sYear; setState(() { origin = DateTime(sYear, 1, 1); endDate = DateTime(eYear, 12, 31); }); Navigator.pop(ctx); _pushHistory(); }, child: const Text('Anwenden')),
        ],
      ),
    );
  }

  Widget _yearField(String label, int value, Function(String) onChanged) => TextField(
        controller: TextEditingController(text: '$value'),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      );

  void _startNewArtifactDialog() async {
    final nameC = TextEditingController();
    final idC = TextEditingController();
    final ownerC = TextEditingController();
    final docC = TextEditingController();
    final notesC = TextEditingController();
    String type = (artifactTypes.isNotEmpty ? artifactTypes.first.key : 'Other');
    DateTime date = DateTime.now();
    final chosenBands = <String>{};
    final chosenEvents = <String>{};

    // IO selections (via chips)
    final inboundSel = <String>{};  // artifacts that flow into THIS
    final outboundSel = <String>{}; // artifacts that THIS flows into

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Artefakt'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: idC, decoration: const InputDecoration(labelText: 'ID (z. B. R-123)')),
              _typeDropdown(type, (v) => type = v ?? type),
              Row(children: [
                const Text('Datum:'), const SizedBox(width: 12),
                TextButton(onPressed: () async { final p = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date); if (p != null) date = p; }, child: Text(_fmtDate(date))),
              ]),
              TextField(controller: ownerC, decoration: const InputDecoration(labelText: 'Ansprechpartner')),
              TextField(controller: docC, decoration: const InputDecoration(labelText: 'Dokument-ID')),
              TextField(controller: notesC, maxLines: 3, decoration: const InputDecoration(labelText: 'Notizen')),
              const SizedBox(height: 10),
              Text('Inputs (wählen → Link von Quelle → dieses Artefakt)', style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in artifacts)
                  FilterChip(
                    avatar: CircleAvatar(backgroundColor: typeByKey(a.type).color, radius: 8),
                    label: Text(a.id),
                    selected: inboundSel.contains(a.id),
                    onSelected: (v) => setState(() => v ? inboundSel.add(a.id) : inboundSel.remove(a.id)),
                  )
              ]),
              const SizedBox(height: 8),
              Text('Outputs (wählen → Link von diesem Artefakt → Ziel)', style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in artifacts)
                  FilterChip(
                    avatar: CircleAvatar(backgroundColor: typeByKey(a.type).color, radius: 8),
                    label: Text(a.id),
                    selected: outboundSel.contains(a.id),
                    onSelected: (v) => setState(() => v ? outboundSel.add(a.id) : outboundSel.remove(a.id)),
                  )
              ]),
              const Divider(height: 18),
              Text('Phasen-Zuordnung', style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final b in bands)
                  FilterChip(
                    avatar: CircleAvatar(backgroundColor: b.color, radius: 8),
                    label: Text(b.label),
                    selected: chosenBands.contains(b.id),
                    onSelected: (v) => setState(() { v ? chosenBands.add(b.id) : chosenBands.remove(b.id); }),
                  )
              ]),
              const SizedBox(height: 8),
              Text('Event-Zuordnung', style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in events)
                  FilterChip(
                    avatar: CircleAvatar(backgroundColor: e.color, radius: 8),
                    label: Text(e.label),
                    selected: chosenEvents.contains(e.id),
                    onSelected: (v) => setState(() { v ? chosenEvents.add(e.id) : chosenEvents.remove(e.id); }),
                  )
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () {
            if (nameC.text.trim().isEmpty || idC.text.trim().isEmpty) return;
            final newArt = Artifact(
              id: idC.text.trim(), name: nameC.text.trim(), type: type,
              owner: ownerC.text.trim(), documentId: docC.text.trim(),
              date: date, y: 120 + (artifacts.length % 6) * 80,
              notes: notesC.text.trim(),
              bandIds: chosenBands.toList(), eventIds: chosenEvents.toList(),
              inputs: inboundSel.toList(), outputs: outboundSel.toList(),
            );
            setState(() {
              artifacts.add(newArt);
              // apply IO links now that artifact exists
              _applyIOSelections(newArt, inboundSel, outboundSel);
            });
            Navigator.pop(ctx); _pushHistory();
          }, child: const Text('Anlegen')),
        ],
      ),
    );
  }

  void _editArtifact(Artifact a) async {
    final nameC = TextEditingController(text: a.name);
    final ownerC = TextEditingController(text: a.owner);
    final docC = TextEditingController(text: a.documentId);
    final notesC = TextEditingController(text: a.notes);
    String type = a.type;
    DateTime date = a.date;
    final chosenBands = a.bandIds.toSet();
    final chosenEvents = a.eventIds.toSet();

    // derive current IO selections from links (authoritative)
    final inboundSel = _inboundOf(a.id).toSet();
    final outboundSel = _outboundOf(a.id).toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.95,
          child: Scaffold(
            appBar: AppBar(title: Text('Artefakt bearbeiten: ${a.id}')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                _typeDropdown(type, (v) => type = v ?? type),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Datum:'), const SizedBox(width: 12),
                  TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date); if (p != null) setState(() => date = p); }, child: Text(_fmtDate(date))),
                ]),
                TextField(controller: ownerC, decoration: const InputDecoration(labelText: 'Ansprechpartner')),
                const SizedBox(height: 8),
                TextField(controller: docC, decoration: const InputDecoration(labelText: 'Dokument-ID')),
                const SizedBox(height: 8),
                TextField(controller: notesC, maxLines: 3, decoration: const InputDecoration(labelText: 'Notizen')),
                const SizedBox(height: 12),
                Text('Inputs (von Quelle → ${a.id})', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final other in artifacts.where((x) => x.id != a.id))
                    FilterChip(
                      avatar: CircleAvatar(backgroundColor: typeByKey(other.type).color, radius: 8),
                      label: Text(other.id),
                      selected: inboundSel.contains(other.id),
                      onSelected: (v) => setState(() => v ? inboundSel.add(other.id) : inboundSel.remove(other.id)),
                    )
                ]),
                const SizedBox(height: 8),
                Text('Outputs (${a.id} → Ziel)', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final other in artifacts.where((x) => x.id != a.id))
                    FilterChip(
                      avatar: CircleAvatar(backgroundColor: typeByKey(other.type).color, radius: 8),
                      label: Text(other.id),
                      selected: outboundSel.contains(other.id),
                      onSelected: (v) => setState(() => v ? outboundSel.add(other.id) : outboundSel.remove(other.id)),
                    )
                ]),
                const SizedBox(height: 12),
                Text('Phasen-Zuordnung', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final b in bands)
                    FilterChip(
                      avatar: CircleAvatar(backgroundColor: b.color, radius: 8),
                      label: Text(b.label),
                      selected: chosenBands.contains(b.id),
                      onSelected: (v) => setState(() { v ? chosenBands.add(b.id) : chosenBands.remove(b.id); }),
                    )
                ]),
                const SizedBox(height: 8),
                Text('Event-Zuordnung', style: Theme.of(ctx).textTheme.titleSmall),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in events)
                    FilterChip(
                      avatar: CircleAvatar(backgroundColor: e.color, radius: 8),
                      label: Text(e.label),
                      selected: chosenEvents.contains(e.id),
                      onSelected: (v) => setState(() { v ? chosenEvents.add(e.id) : chosenEvents.remove(e.id); }),
                    )
                ]),
                const SizedBox(height: 16),
                const Text('Verknüpfte Links'),
                const SizedBox(height: 6),
                ...links.where((l) => l.fromId == a.id || l.toId == a.id).map((l) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.link),
                      title: Text('${l.fromId} → ${l.toId}'),
                      subtitle: Text(l.label.isEmpty ? '(ohne Label)' : l.label),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Label bearbeiten', icon: const Icon(Icons.edit), onPressed: () => _editLink(l)),
                        IconButton(tooltip: 'Link löschen', icon: const Icon(Icons.delete_outline), onPressed: () { setState(() => links.remove(l)); _pushHistory(); }),
                      ]),
                    )),
                const SizedBox(height: 20),
                Row(children: [
                  OutlinedButton.icon(onPressed: () { setState(() { artifacts.removeWhere((x) => x.id == a.id); links.removeWhere((l) => l.fromId == a.id || l.toId == a.id); _setFocus(null); }); Navigator.pop(ctx); _pushHistory(); }, icon: const Icon(Icons.delete_outline), label: const Text('Artefakt löschen')),
                  const Spacer(),
                  FilledButton.icon(onPressed: () {
                    setState(() {
                      a.name = nameC.text.trim();
                      a.type = type;
                      a.owner = ownerC.text.trim();
                      a.documentId = docC.text.trim();
                      a.notes = notesC.text.trim();
                      a.date = date;
                      a.bandIds = chosenBands.toList();
                      a.eventIds = chosenEvents.toList();
                      _applyIOSelections(a, inboundSel, outboundSel);
                    });
                    Navigator.pop(ctx);
                    _pushHistory();
                  }, icon: const Icon(Icons.save), label: const Text('Speichern'))
                ])
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _editLink(Link l) async {
    final labelC = TextEditingController(text: l.label);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Link bearbeiten: ${l.id}'),
        content: TextField(controller: labelC, decoration: const InputDecoration(labelText: 'Label')),
        actions: [
          TextButton(onPressed: () { setState(() => links.remove(l)); Navigator.pop(ctx); _pushHistory(); }, child: const Text('Löschen')),
          FilledButton(onPressed: () { setState(() => l.label = labelC.text.trim()); Navigator.pop(ctx); _pushHistory(); }, child: const Text('Speichern')),
        ],
      ),
    );
  }

  void _manageTypes() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        final nameC = TextEditingController();
        Color chosen = Colors.primaries[(artifactTypes.length) % Colors.primaries.length];
        return StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
              title: const Text('Artifact Types verwalten'),
              content: SizedBox(
                width: 520,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ...artifactTypes.map((t) => ListTile(leading: CircleAvatar(backgroundColor: t.color), title: Text(t.key), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Farbe ändern', icon: const Icon(Icons.color_lens_outlined), onPressed: () async { final c = await _pickColor(ctx, initial: t.color); if (c != null) setState(() { t.colorValue = c.value; _pushHistory(); }); }),
                        IconButton(tooltip: 'Umbenennen', icon: const Icon(Icons.edit), onPressed: () async {
                          final nc = TextEditingController(text: t.key);
                          await showDialog(context: ctx, builder: (c2) => AlertDialog(
                                title: const Text('Typ umbenennen'),
                                content: TextField(controller: nc, decoration: const InputDecoration(labelText: 'Name')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c2), child: const Text('Abbrechen')),
                                  FilledButton(onPressed: () { setState(() { t.key = nc.text.trim(); _pushHistory(); }); Navigator.pop(c2); }, child: const Text('Speichern'))
                                ],
                              ));
                        }),
                        IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: () { setState(() { artifactTypes.remove(t); _pushHistory(); }); }),
                      ]))),
                  const Divider(),
                  Align(alignment: Alignment.centerLeft, child: Text('Neuen Typ hinzufügen', style: Theme.of(ctx).textTheme.titleSmall)),
                  const SizedBox(height: 8),
                  TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [ for (final c in Colors.primaries) GestureDetector(onTap: () => setLocal(() => chosen = c), child: CircleAvatar(radius: 12, backgroundColor: c, child: chosen == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null)) ]),
                ]),
              ),
              actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')), FilledButton(onPressed: () { if (nameC.text.trim().isEmpty) return; setState(() { artifactTypes.add(ArtifactType(nameC.text.trim(), chosen)); _pushHistory(); }); }, child: const Text('Hinzufügen')), ],
            ));
      },
    );
  }

  void _manageBands() async {
    await showDialog(context: context, builder: (ctx) {
      final labelC = TextEditingController();
      final typeC = TextEditingController();
      DateTime start = origin;
      DateTime end = endDate;
      Color chosen = Colors.teal;
      return StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Zeit-Bänder verwalten'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...bands.map((b) => ListTile(leading: CircleAvatar(backgroundColor: b.color), title: Text('${b.label} (${_fmtDate(b.start)} → ${_fmtDate(b.end)})'), subtitle: Text(b.type.isEmpty ? '—' : b.type), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.color_lens_outlined), onPressed: () async { final c = await _pickColor(ctx, initial: b.color); if (c != null) setState(() { b.colorValue = c.value; _pushHistory(); }); }),
                IconButton(icon: const Icon(Icons.edit), onPressed: () async {
                  final lc = TextEditingController(text: b.label);
                  final tc = TextEditingController(text: b.type);
                  DateTime s = b.start;
                  DateTime e = b.end;
                  await showDialog(context: ctx, builder: (c2) => AlertDialog(
                        title: const Text('Band bearbeiten'),
                        content: Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(controller: lc, decoration: const InputDecoration(labelText: 'Label')),
                          TextField(controller: tc, decoration: const InputDecoration(labelText: 'Typ')),
                          Row(children: [
                            const Text('Start:'), const SizedBox(width: 8),
                            TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: s); if (p != null) setLocal(() => s = p); }, child: Text(_fmtDate(s))),
                            const SizedBox(width: 8), const Text('Ende:'),
                            const SizedBox(width: 8),
                            TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: e); if (p != null) setLocal(() => e = p); }, child: Text(_fmtDate(e))),
                          ]),
                        ]),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c2), child: const Text('Abbrechen')),
                          FilledButton(onPressed: () { setState(() { b.label = lc.text.trim(); b.type = tc.text.trim(); b.start = s; b.end = e; _pushHistory(); }); Navigator.pop(c2); }, child: const Text('Speichern')),
                        ],
                      ));
                }),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() { bands.remove(b); _pushHistory(); }); }),
              ]))),
          const Divider(),
          Align(alignment: Alignment.centerLeft, child: Text('Neues Band hinzufügen', style: Theme.of(ctx).textTheme.titleSmall)),
          const SizedBox(height: 8),
          TextField(controller: labelC, decoration: const InputDecoration(labelText: 'Label')),
          TextField(controller: typeC, decoration: const InputDecoration(labelText: 'Typ (optional)')),
          const SizedBox(height: 8),
          Row(children: [ const Text('Start:'), const SizedBox(width: 8), TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: start); if (p != null) setLocal(() => start = p); }, child: Text(_fmtDate(start))), const SizedBox(width: 12), const Text('Ende:'), const SizedBox(width: 8), TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: end); if (p != null) setLocal(() => end = p); }, child: Text(_fmtDate(end))), ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [ for (final c in Colors.primaries) GestureDetector(onTap: () => setLocal(() => chosen = c), child: CircleAvatar(radius: 12, backgroundColor: c, child: chosen == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null)) ]),
        ]))),
        actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')), FilledButton(onPressed: () { if (labelC.text.trim().isEmpty) return; setState(() { bands.add(TimeBand(id: 'B${DateTime.now().microsecondsSinceEpoch}', label: labelC.text.trim(), color: chosen, type: typeC.text.trim(), start: start, end: end)); _pushHistory(); }); }, child: const Text('Hinzufügen')) ],
      ));
    });
  }

  void _manageEvents() async {
    await showDialog(context: context, builder: (ctx) {
      final labelC = TextEditingController();
      final typeC = TextEditingController();
      DateTime date = DateTime.now();
      Color chosen = Colors.pink;
      return StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Events verwalten'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...events.map((e) => ListTile(
                leading: CircleAvatar(backgroundColor: e.color),
                title: Text('${e.label} (${_fmtDate(e.date)})'),
                subtitle: Text(e.type.isEmpty ? '—' : e.type),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.color_lens_outlined), onPressed: () async { final c = await _pickColor(ctx, initial: e.color); if (c != null) setState(() { e.colorValue = c.value; _pushHistory(); }); }),
                  IconButton(icon: const Icon(Icons.edit), onPressed: () async {
                    final lc = TextEditingController(text: e.label);
                    final tc = TextEditingController(text: e.type);
                    DateTime d = e.date;
                    await showDialog(context: ctx, builder: (c2) => AlertDialog(
                      title: const Text('Event bearbeiten'),
                      content: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(controller: lc, decoration: const InputDecoration(labelText: 'Label')),
                        TextField(controller: tc, decoration: const InputDecoration(labelText: 'Typ')),
                        Row(children: [ const Text('Datum:'), const SizedBox(width: 8),
                          TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: d); if (p != null) setLocal(() => d = p); }, child: Text(_fmtDate(d))),
                        ])
                      ]),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c2), child: const Text('Abbrechen')),
                        FilledButton(onPressed: () { setState(() { e.label = lc.text.trim(); e.type = tc.text.trim(); e.date = d; _pushHistory(); }); Navigator.pop(c2); }, child: const Text('Speichern')),
                      ],
                    ));
                  }),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() { events.remove(e); for (final a in artifacts) { a.eventIds.remove(e.id); } _pushHistory(); }); }),
                ]),
              )),
          const Divider(),
          Align(alignment: Alignment.centerLeft, child: Text('Neues Event hinzufügen', style: Theme.of(ctx).textTheme.titleSmall)),
          const SizedBox(height: 8),
          TextField(controller: labelC, decoration: const InputDecoration(labelText: 'Label')),
          TextField(controller: typeC, decoration: const InputDecoration(labelText: 'Typ (optional)')),
          const SizedBox(height: 8),
          Row(children: [ const Text('Datum:'), const SizedBox(width: 8), TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date); if (p != null) setLocal(() => date = p); }, child: Text(_fmtDate(date))), ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [ for (final c in Colors.primaries) GestureDetector(onTap: () => setLocal(() => chosen = c), child: CircleAvatar(radius: 12, backgroundColor: c, child: chosen == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null)) ]),
        ]))),
        actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')), FilledButton(onPressed: () { if (labelC.text.trim().isEmpty) return; setState(() { events.add(TimeEvent(id: 'E${DateTime.now().microsecondsSinceEpoch}', label: labelC.text.trim(), type: typeC.text.trim(), color: chosen, date: date)); _pushHistory(); }); }, child: const Text('Hinzufügen')) ],
      ));
    });
  }

  void _openTimeRangeDialog() async {
    DateTime s = origin;
    DateTime e = endDate;
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Zeitraum einstellen'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [ const Text('Start:'), const SizedBox(width: 8), TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: s); if (p != null) s = p; }, child: Text(_fmtDate(s))), ]),
        Row(children: [ const Text('Ende :'), const SizedBox(width: 8), TextButton(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: e); if (p != null) e = p; }, child: Text(_fmtDate(e))), ]),
      ])),
      actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')), FilledButton(onPressed: () { setState(() { origin = s; endDate = e; }); Navigator.pop(ctx); _pushHistory(); }, child: const Text('Speichern')) ],
    ));
  }

  Future<Color?> _pickColor(BuildContext context, {required Color initial}) async {
    Color chosen = initial;
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Farbe wählen'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in Colors.primaries)
              GestureDetector(
                onTap: () => chosen = c,
                onDoubleTap: () => Navigator.pop(ctx, c),
                child: CircleAvatar(radius: 14, backgroundColor: c, child: c == chosen ? const Icon(Icons.check, color: Colors.white) : null),
              )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, chosen), child: const Text('OK')),
        ],
      ),
    );
  }

  void _exportJson() {
    final data = _serialize();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export JSON'),
        content: SizedBox(width: 640, child: SelectableText(data, maxLines: 24)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _importJson() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import JSON'),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: controller,
            maxLines: 18,
            decoration: const InputDecoration(hintText: 'JSON hier einfügen...'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              try {
                setState(() {
                  _restore(controller.text);
                  _pushHistory();
                });
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import-Fehler: $e')));
              }
            },
            child: const Text('Importieren'),
          )
        ],
      ),
    );
  }

  // --------------------------- Build ---------------------------------------
  @override
  Widget build(BuildContext context) {
    final daysRange = endDate.difference(origin).inDays.abs().clamp(1, 10000);
    final canvasWidth = 140 + daysRange * pxPerDay + 200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Traceability — MAX v2.5'),
        actions: [
          IconButton(tooltip: 'Undo', onPressed: _historyIndex > 0 ? _undo : null, icon: const Icon(Icons.undo)),
          IconButton(tooltip: 'Redo', onPressed: _historyIndex < _history.length - 1 ? _redo : null, icon: const Icon(Icons.redo)),
          IconButton(tooltip: 'Typen verwalten', onPressed: _manageTypes, icon: const Icon(Icons.category_outlined)),
          IconButton(tooltip: 'Zeit-Bänder', onPressed: _manageBands, icon: const Icon(Icons.label_outline)),
          IconButton(tooltip: 'Events', onPressed: _manageEvents, icon: const Icon(Icons.push_pin_outlined)),
          IconButton(tooltip: 'Band-Layout', onPressed: _openBandLayoutDialog, icon: const Icon(Icons.movie_creation_outlined)),
          IconButton(tooltip: 'Filter (Phasen/Events)', onPressed: _openFilterDialog, icon: const Icon(Icons.filter_alt_outlined)),
          IconButton(tooltip: 'Jahresfilter', onPressed: _openYearFilterDialog, icon: const Icon(Icons.calendar_month_outlined)),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Fokus löschen',
            onPressed: focusArtifactId != null ? () => _setFocus(null) : null,
            icon: const Icon(Icons.highlight_off),
          ),
          IconButton(
            tooltip: focusDimOthers ? 'Fokus: Dimmen' : 'Fokus: Ausblenden',
            onPressed: focusArtifactId != null ? () => setState(() { focusDimOthers = !focusDimOthers; _pushHistory(); }) : null,
            icon: Icon(focusDimOthers ? Icons.tonality : Icons.visibility_off),
          ),
          IconButton(tooltip: 'Export JSON', onPressed: _exportJson, icon: const Icon(Icons.upload)),
          IconButton(tooltip: 'Import JSON', onPressed: _importJson, icon: const Icon(Icons.download)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            FilledButton.icon(onPressed: _startNewArtifactDialog, icon: const Icon(Icons.add), label: const Text('Artifact')),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: _toggleLinkMode, icon: Icon(linkMode ? Icons.link_off : Icons.link), label: Text(linkMode ? 'Link-Modus AUS' : 'Link-Modus EIN')),
            const SizedBox(width: 16),
            const Text('px/Tag'),
            Slider(value: pxPerDay, min: 4, max: 40, onChanged: (v) => setState(() => pxPerDay = v)),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: _openTimeRangeDialog, icon: const Icon(Icons.date_range), label: const Text('Zeitraum')),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                final days = endDate.difference(origin).inDays.abs();
                if (days > 0) setState(() => pxPerDay = ((MediaQuery.of(context).size.width - 200) / days).clamp(4, 200));
              },
              icon: const Icon(Icons.fit_screen),
              label: const Text('Fit to Range'),
            ),
            const SizedBox(width: 16),
            DropdownButton<String?>(
              value: typeFilter,
              hint: const Text('Typ-Filter'),
              items: [const DropdownMenuItem(value: null, child: Text('Alle')), ...artifactTypes.map((t) => DropdownMenuItem(value: t.key, child: Text(t.key)))],
              onChanged: (v) => setState(() => typeFilter = v),
            ),
            const SizedBox(width: 8),
            Checkbox(value: showOnlyUnlinked, onChanged: (v) => setState(() => showOnlyUnlinked = v ?? false)),
            const Text('nur Unverlinkte'),
            const SizedBox(width: 8),
            Checkbox(value: dimFiltered, onChanged: (v) => setState(() => dimFiltered = v ?? false)),
            const Text('statt Ausblenden: Dimmen'),
            const SizedBox(width: 16),
            Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Suche Name/ID/Owner/Dok-ID'), onChanged: (v) => setState(() => search = v))),
          ]),
        ),
        const SizedBox(height: 8),
        // Canvas
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 2.5,
            constrained: false,
            child: SizedBox(
              width: canvasWidth,
              height: canvasHeight,
              child: Stack(children: [
                // grid + links painter (under everything)
                Positioned.fill(
                  child: CustomPaint(
                    painter: TimelinePainter(
                      origin: origin,
                      endDate: endDate,
                      pxPerDay: pxPerDay,
                      artifacts: artifactsToDraw,
                      links: linksToDraw,
                      typeByKey: typeByKey,
                      posOfId: positionOfId,
                      dimMode: dimFiltered,
                      allArtifacts: artifacts,
                      allLinks: links,
                      isArtifactVisible: visibleArtifact,
                      isLinkVisible: visibleLink,
                      bands: bands,
                      events: events,
                      bandStackMode: bandStackMode,
                      bandOpacity: bandOpacity,
                      bandRowHeight: bandRowHeight,
                      bandRowGap: bandRowGap,
                      focusArtifactId: focusArtifactId,
                      focusedLinkIds: _focusedLinkIds,
                      focusDimOthers: focusDimOthers,
                    ),
                  ),
                ),

                // overlay for exiting link mode — placed UNDER nodes so taps on nodes still work
                if (linkMode) Positioned.fill(child: IgnorePointer(ignoring: true, child: Container(color: Colors.transparent))),

                // link labels / link nodes
                ...links.where((l) => dimFiltered ? true : visibleLink(l)).map((l) {
                  final pos = positionOfId(l.id);
                  if (pos == null) return const SizedBox.shrink();
                  final inFocus = focusArtifactId == null || _focusedLinkIds.contains(l.id);
                  final baseVisible = visibleLink(l);
                  final opacityFocus = (focusArtifactId != null && !inFocus && focusDimOthers) ? 0.18 : 1.0;
                  final opacityFiltered = (dimFiltered && !baseVisible) ? 0.25 : 1.0;
                  final combinedOpacity = (opacityFocus * opacityFiltered).clamp(0.0, 1.0);
                  return Positioned(
                    left: pos.dx - 70,
                    top: pos.dy - 40,
                    child: Opacity(
                      opacity: combinedOpacity,
                      child: GestureDetector(
                        onTap: () {
                          if (!linkMode) return;
                          setState(() {
                            if (pendingLinkFromId == null) {
                              pendingLinkFromId = l.id;
                            } else if (pendingLinkFromId == l.id) {
                              pendingLinkFromId = null;
                            } else {
                              links.add(Link(id: 'L${DateTime.now().microsecondsSinceEpoch}', fromId: pendingLinkFromId!, toId: l.id));
                              pendingLinkFromId = null; linkMode = false; _pushHistory();
                            }
                          });
                        },
                        onDoubleTap: () => _editLink(l),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x22000000))], border: Border.all(color: Colors.black12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [ const Icon(Icons.link, size: 14), const SizedBox(width: 6), Text(l.label.isEmpty ? l.id : l.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)) ]),
                        ),
                      ),
                    ),
                  );
                }),

                // artifacts
                ...artifacts.map((a) {
                  final isVis = visibleArtifact(a);
                  if (!dimFiltered && !isVis) return const SizedBox.shrink();
                  final basePos = Offset(xForDate(a.date), a.y);
                  final pos = _dragPosOverride[a.id] ?? basePos;
                  final t = typeByKey(a.type);
                  final selected = linkMode && pendingLinkFromId == a.id;

                  // focus dimming
                  final inFocus = focusArtifactId == null || _focusedArtifactIds.contains(a.id);
                  final focusOpacity = (focusArtifactId != null && !inFocus && focusDimOthers) ? 0.22 : 1.0;

                  final filteredOpacity = dimFiltered && !isVis ? 0.25 : 1.0;
                  final opacity = (focusOpacity * filteredOpacity).clamp(0.0, 1.0);

                  return Positioned(
                    left: pos.dx - 70,
                    top: pos.dy - 22,
                    child: GestureDetector(
                      onTap: () {
                        if (!linkMode) return;
                        setState(() {
                          if (pendingLinkFromId == null) {
                            pendingLinkFromId = a.id;
                          } else if (pendingLinkFromId == a.id) {
                            pendingLinkFromId = null;
                          } else {
                            links.add(Link(id: 'L${DateTime.now().microsecondsSinceEpoch}', fromId: pendingLinkFromId!, toId: a.id));
                            pendingLinkFromId = null; linkMode = false; _pushHistory();
                          }
                        });
                      },
                      onLongPress: () { // toggle focus on long press
                        if (focusArtifactId == a.id) {
                          _setFocus(null);
                        } else {
                          _setFocus(a.id);
                        }
                      },
                      onDoubleTap: () => _editArtifact(a),
                      onPanStart: (_) { _dragPosOverride[a.id] = basePos; setState(() {}); },
                      onPanUpdate: (d) { final prev = _dragPosOverride[a.id] ?? basePos; final next = Offset(prev.dx + d.delta.dx, (prev.dy + d.delta.dy).clamp(60, canvasHeight - 40)); _dragPosOverride[a.id] = next; setState(() {}); },
                      onPanEnd: (_) { final endPos = _dragPosOverride[a.id] ?? basePos; setState(() { a.date = dateForX(endPos.dx); a.y = endPos.dy; _dragPosOverride.remove(a.id); }); _pushHistory(); },
                      child: Opacity(
                        opacity: opacity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: selected ? t.color.withOpacity(0.95) : t.color.withOpacity(0.88), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x22000000))], border: Border.all(color: focusArtifactId == a.id ? Colors.yellowAccent : Colors.white, width: focusArtifactId == a.id ? 2.2 : 1.2)),
                          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${a.id} · ${a.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            Row(children: [
                              Text(a.owner.isEmpty ? '' : a.owner, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              if (a.documentId.isNotEmpty) ...[ const SizedBox(width: 6), Text(a.documentId, style: const TextStyle(color: Colors.white70, fontSize: 10)), ]
                            ])
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ),
        // Legend + Info
        Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, -2), color: Color(0x14000000))]),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Text('Legende:'),
            const SizedBox(width: 8),
            Wrap(spacing: 10, children: [for (final t in artifactTypes) Chip(label: Text(t.key, style: const TextStyle(color: Colors.white)), backgroundColor: t.color.withOpacity(0.95))]),
            const Spacer(),
            if (focusArtifactId != null) Row(children: [
              const Icon(Icons.highlight_alt, size: 18),
              const SizedBox(width: 6),
              Text('Fokus: $focusArtifactId (${focusDimOthers ? "dimmen" : "ausblenden"})'),
              const SizedBox(width: 14),
            ]),
            Row(children: [
              Icon(bandStackMode ? Icons.view_agenda_outlined : Icons.layers_outlined, size: 18),
              const SizedBox(width: 6),
              Text(bandStackMode ? 'Bands: gestapelt' : 'Bands: überlappend'),
              const SizedBox(width: 12),
              Icon(Icons.push_pin_outlined, size: 18),
              const SizedBox(width: 6),
              Text('Events: ${events.length}'),
            ]),
            const SizedBox(width: 16),
            Text('Artefakte: ${artifacts.length} · Links: ${links.length}')
          ]),
        )
      ]),
    );
  }

  // --------------------------- Widgets -------------------------------------
  DropdownButtonFormField<String> _typeDropdown(String value, void Function(String?) onChanged) =>
      DropdownButtonFormField<String>(value: value, decoration: const InputDecoration(labelText: 'Typ'), items: [
        for (final t in artifactTypes) DropdownMenuItem(value: t.key, child: Text(t.key))
      ], onChanged: onChanged);
}

// ------------------------- Timeline Painter --------------------------------
class TimelinePainter extends CustomPainter {
  final DateTime origin;
  final DateTime endDate;
  final double pxPerDay;
  final List<Artifact> artifacts;
  final List<Link> links;
  final ArtifactType Function(String) typeByKey;
  final Offset? Function(String id) posOfId;
  final bool dimMode;
  final List<Artifact> allArtifacts;
  final List<Link> allLinks;
  final bool Function(Artifact) isArtifactVisible;
  final bool Function(Link) isLinkVisible;
  final List<TimeBand> bands;
  final List<TimeEvent> events;

  // band layout
  final bool bandStackMode;
  final double bandOpacity; // overlap mode
  final double bandRowHeight; // stacked mode
  final double bandRowGap; // stacked mode

  // focus
  final String? focusArtifactId;
  final Set<String> focusedLinkIds;
  final bool focusDimOthers;

  TimelinePainter({
    required this.origin,
    required this.endDate,
    required this.pxPerDay,
    required this.artifacts,
    required this.links,
    required this.typeByKey,
    required this.posOfId,
    required this.dimMode,
    required this.allArtifacts,
    required this.allLinks,
    required this.isArtifactVisible,
    required this.isLinkVisible,
    required this.bands,
    required this.events,
    required this.bandStackMode,
    required this.bandOpacity,
    required this.bandRowHeight,
    required this.bandRowGap,
    required this.focusArtifactId,
    required this.focusedLinkIds,
    required this.focusDimOthers,
  });

  double xForDate(DateTime d) => d.difference(origin).inDays * pxPerDay + 140;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = const Color(0x11000000)..strokeWidth = 1;
    final monthPaint = Paint()..color = const Color(0x22000000)..strokeWidth = 2;

    // horizontal lanes
    for (double y = 60; y <= size.height - 60; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // vertical day ticks + month headers
    final endDays = endDate.difference(origin).inDays;
    DateTime iter = origin;
    for (int i = 0; i <= endDays; i++) {
      final x = xForDate(iter);
      if (iter.day == 1) {
        canvas.drawLine(Offset(x, 16), Offset(x, size.height - 40), monthPaint);
        _text(canvas, '${iter.year}-${iter.month.toString().padLeft(2, '0')}', Offset(x + 4, 0), 12, const Color(0x88000000));
      } else {
        canvas.drawLine(Offset(x, 28), Offset(x, size.height - 40), gridPaint);
      }
      if (i % 7 == 0) {
        _text(canvas, '${iter.month}/${iter.day}', Offset(x + 2, 28), 10, const Color(0x66000000));
      }
      iter = iter.add(const Duration(days: 1));
    }

    // Bands (bottom)
    if (bands.isNotEmpty) {
      if (!bandStackMode) {
        final bandTop = size.height - 36;
        for (final b in bands) {
          final sX = xForDate(b.start);
          final eX = xForDate(b.end);
          final rect = Rect.fromLTRB(sX, bandTop, eX, bandTop + 20);
          final r = RRect.fromRectAndRadius(rect, const Radius.circular(6));
          final paint = Paint()..color = b.color.withOpacity(bandOpacity.clamp(0.0, 1.0));
          canvas.drawRRect(r, paint);
          _text(canvas, b.label, Offset(sX + 6, bandTop + 2), 11, Colors.white);
        }
      } else {
        final assigned = _assignBandLanes(bands);
        final laneCount = assigned.values.fold<int>(0, (maxL, lane) => math.max(maxL, lane + 1));
        final totalHeight = laneCount * bandRowHeight + (laneCount - 1) * bandRowGap;
        final baseTop = size.height - 16 - totalHeight;
        for (final b in bands) {
          final lane = assigned[b.id] ?? 0;
          final top = baseTop + lane * (bandRowHeight + bandRowGap);
          final sX = xForDate(b.start);
          final eX = xForDate(b.end);
          final rect = Rect.fromLTRB(sX, top, eX, top + bandRowHeight);
          final r = RRect.fromRectAndRadius(rect, const Radius.circular(6));
          final paint = Paint()..color = b.color.withOpacity(0.95);
          final border = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black.withOpacity(0.12);
          canvas.drawRRect(r, paint);
          canvas.drawRRect(r, border);
          _text(canvas, b.label, Offset(sX + 6, top + (bandRowHeight - 14) / 2), 11, Colors.white);
        }
      }
    }

    // Events (pins near top)
    if (events.isNotEmpty) {
      for (final e in events) {
        final x = xForDate(e.date);
        final topY = 46.0;
        final stemH = 18.0;
        final circleR = 4.5;

        // stem
        canvas.drawLine(Offset(x, topY), Offset(x, topY + stemH), Paint()..color = e.color.withOpacity(0.85)..strokeWidth = 2);

        // pin head (circle)
        canvas.drawCircle(Offset(x, topY), circleR, Paint()..color = e.color.withOpacity(0.95));

        // label bubble
        final label = e.label;
        final tp = TextPainter(text: TextSpan(text: label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x + 6, topY - tp.height - 4, tp.width + 10, tp.height + 6), const Radius.circular(6));
        canvas.drawRRect(rect, Paint()..color = e.color.withOpacity(0.95));
        tp.paint(canvas, Offset(x + 11, topY - tp.height - 1));
      }
    }

    // Draw links as cubic curves
    for (final l in allLinks) {
      final pFrom = posOfId(l.fromId);
      final pTo = posOfId(l.toId);
      if (pFrom == null || pTo == null) continue;

      final globallyVisible = isLinkVisible(l);
      if (!globallyVisible && !dimMode) continue;

      final inFocus = focusArtifactId == null || focusedLinkIds.contains(l.id);
      if (focusArtifactId != null && !inFocus && !focusDimOthers) {
        // hide non-focused links when focus is "hide"
        continue;
      }

      final midX = (pFrom.dx + pTo.dx) / 2;
      final path = Path()..moveTo(pFrom.dx, pFrom.dy)..cubicTo(midX, pFrom.dy, midX, pTo.dy, pTo.dx, pTo.dy);

      final fromArt = allArtifacts.firstWhereOrNull((a) => a.id == l.fromId);
      final baseColor = fromArt != null ? typeByKey(fromArt.type).color : const Color(0xFF475569);
      double baseOpacity = globallyVisible ? 0.9 : 0.18;
      if (focusArtifactId != null && !inFocus && focusDimOthers) {
        baseOpacity = baseOpacity * 0.22;
      }
      final color = baseColor.withOpacity(baseOpacity.clamp(0.0, 1.0));
      final glowAlpha = globallyVisible ? 0.22 : 0.06;
      final glow = Paint()..color = color.withOpacity(glowAlpha)..style = PaintingStyle.stroke..strokeWidth = 6;
      final pen = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.6;
      canvas.drawPath(path, glow);
      canvas.drawPath(path, pen);
      _arrowHead(canvas, Offset(pTo.dx, pTo.dy), Offset(midX, pTo.dy), color);
    }

    _text(canvas, 'Zeitachse (Tage)', Offset(12, size.height - 22), 12, const Color(0x88000000));
  }

  Map<String, int> _assignBandLanes(List<TimeBand> items) {
    final sorted = [...items]..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : a.end.compareTo(b.end);
      });
    final laneEnds = <DateTime>[];
    final out = <String, int>{};
    for (final b in sorted) {
      int laneIndex = -1;
      for (int i = 0; i < laneEnds.length; i++) {
        if (b.start.isAfter(laneEnds[i])) {
          laneIndex = i;
          break;
        }
      }
      if (laneIndex == -1) {
        laneEnds.add(b.end);
        laneIndex = laneEnds.length - 1;
      } else {
        laneEnds[laneIndex] = b.end;
      }
      out[b.id] = laneIndex;
    }
    return out;
  }

  void _arrowHead(Canvas canvas, Offset tip, Offset from, Color color) {
    final ang = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    const s = 7.0;
    final p = Path()..moveTo(tip.dx, tip.dy)..lineTo(tip.dx - s * math.cos(ang - math.pi / 6), tip.dy - s * math.sin(ang - math.pi / 6))..lineTo(tip.dx - s * math.cos(ang + math.pi / 6), tip.dy - s * math.sin(ang + math.pi / 6))..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _text(Canvas c, String s, Offset o, double size, Color color) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant TimelinePainter old) => true;
}