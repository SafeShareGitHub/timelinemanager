import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/classes/link.dart';
import 'package:timelinemanager/classes/person.dart';
import 'package:timelinemanager/classes/qualitygate.dart';
import 'package:timelinemanager/classes/timeEvent.dart';
import 'package:timelinemanager/classes/timeband.dart';
import 'package:timelinemanager/classes/todo.dart';
import 'package:timelinemanager/platform/external_open.dart';
import 'package:timelinemanager/platform/session_store.dart';
import 'package:timelinemanager/state/filter_types.dart';
import 'package:timelinemanager/utils/iterable_ext.dart';

const String kDefaultTimelineTitle = 'Timeline Traceability — MAX v2.5';

/// One stored project: the title we show in the dropdown plus the
/// serialized timeline JSON. Mutated in place as the user works on the
/// active project so the dropdown stays in sync.
class _ProjectSlot {
  String title;
  String dataJson;
  _ProjectSlot(this.title, this.dataJson);
}

class TimelineController extends ChangeNotifier {
  // ---------------- Data ----------------
  String timelineTitle = kDefaultTimelineTitle;

  /// Second, free-text part of the heading shown next to [timelineTitle]
  /// in the app bar, with copy-to-clipboard and open-link affordances.
  String timelineSubtitle = '';

  /// Optional web link associated with the heading. Opened directly when
  /// the user clicks the link icon in the app bar.
  String timelineLink = '';

  final List<Artifact> artifacts = [];
  final List<Link> links = [];

  /// Org chart entries. Their names feed the auto-suggest in artifact
  /// owner/assignee fields.
  final List<Person> people = [];

  /// User-defined quality gates. Artifacts reference them by id.
  final List<QualityGate> qualityGates = [];

  /// Project-level to-dos that are not attached to any artifact. Shown in
  /// the global to-do panel alongside the artifact to-dos.
  final List<TodoItem> globalTodos = [];
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

  // ---------------- Timeline config ----------------
  DateTime origin = DateTime.now().subtract(const Duration(days: 90));
  DateTime endDate = DateTime.now().add(const Duration(days: 30));
  double pxPerDay = 24;
  double canvasHeight = 4000;

  // ---------------- Band layout ----------------
  bool bandStackMode = false;
  double bandOpacity = 0.6;
  double bandRowHeight = 22;
  double bandRowGap = 6;

  // ---------------- Filters ----------------
  String? typeFilter;
  ArtifactFilter artifactFilter = ArtifactFilter.none;
  String search = '';
  bool dimFiltered = false;

  final Set<String> selectedBandIds = {};
  final Set<String> selectedEventIds = {};
  FilterMode filterMode = FilterMode.ignore;

  // ---------------- Focus ----------------
  String? focusArtifactId;
  bool focusDimOthers = true;
  Set<String> focusedArtifactIds = {};
  Set<String> focusedLinkIds = {};
  int focusDepth = 1;

  // ---------------- Link mode ----------------
  bool linkMode = false;
  String? pendingLinkFromId;

  // ---------------- Drag ----------------
  final Map<String, Offset> dragPosOverride = {};

  // ---------------- History ----------------
  final List<String> _history = [];
  int _historyIndex = -1;

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  // ---------------- Projects ----------------
  final List<_ProjectSlot> _projects = [];
  int _currentProjectIndex = 0;

  int get projectCount => _projects.length;
  int get currentProjectIndex => _currentProjectIndex;
  List<String> get projectTitles =>
      _projects.map((p) => p.title).toList(growable: false);
  bool get canDeleteCurrentProject => _projects.length > 1;

  // ---------------- Machine-local settings ----------------
  /// Prepended to relative `linkedFile` entries when opening external
  /// documents. Persisted in session.json (top-level, not per project) so
  /// each user keeps their own path even when sharing a session.
  String basePath = '';

  void setBasePath(String value) {
    final next = stripPathQuotes(value);
    if (basePath == next) return;
    basePath = next;
    _scheduleAutosave();
    notifyListeners();
  }

  /// Removes leading/trailing whitespace and a single layer of wrapping
  /// double quotes — Windows' "Copy as path" hands you `"C:\…\x.docx"`.
  static String stripPathQuotes(String raw) {
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  /// Combines [basePath] with a linked-file entry. Strips wrapping quotes
  /// first, then returns the path unchanged if it already looks absolute
  /// (Windows drive letter or UNC, or starts with `/`).
  String resolveLinkedFile(String linkedFile) {
    final raw = stripPathQuotes(linkedFile);
    if (raw.isEmpty) return '';
    final isAbsolute =
        raw.startsWith(RegExp(r'^[a-zA-Z]:[\\/]')) ||
        raw.startsWith(r'\\') ||
        raw.startsWith('/');
    if (isAbsolute || basePath.isEmpty) return raw;
    final prefix = basePath.endsWith(r'\') || basePath.endsWith('/')
        ? basePath
        : '$basePath\\';
    return '$prefix$raw';
  }

  /// Convenience: resolve + shell-open. Returns the OS result so callers
  /// can surface failures (file missing, etc).
  Future<ExternalOpenResult> openArtifactFile(String linkedFile) =>
      openExternally(resolveLinkedFile(linkedFile));

  // ---------------- Autosave ----------------
  Timer? _autosaveTimer;
  static const Duration _autosaveDebounce = Duration(milliseconds: 800);

  TimelineController() {
    final session = readSessionSync();
    if (session != null && session.projects.isNotEmpty) {
      basePath = session.basePath;
      for (final p in session.projects) {
        _projects.add(_ProjectSlot(p.title, p.dataJson));
      }
      _currentProjectIndex =
          session.currentIndex.clamp(0, _projects.length - 1);
      restore(_projects[_currentProjectIndex].dataJson);
      pushHistory();
      return;
    }
    _seedDemo();
    _projects.add(_ProjectSlot(timelineTitle, ''));
    _currentProjectIndex = 0;
    pushHistory();
  }

  // ---------------- Mutation helpers ----------------
  /// Mutates state and notifies listeners. Use for transient changes
  /// that should NOT enter undo history (e.g. live slider drags).
  void update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Mutates state, notifies listeners, and snapshots into undo history.
  void commit(VoidCallback fn) {
    fn();
    notifyListeners();
    pushHistory();
  }

  // ---------------- Demo seed ----------------
  void _seedDemo() {
    final now = DateTime.now();
    artifacts.addAll([
      Artifact(
        id: 'R-101',
        name: 'Door shall auto-lock',
        type: 'Requirement',
        owner: 'PM',
        documentId: 'REQ-101',
        date: now.subtract(const Duration(days: 80)),
        y: 120,
        inputs: ['SRD-1'],
        outputs: ['S-12'],
      ),
      Artifact(
        id: 'S-12',
        name: 'Locking Spec v1',
        type: 'Spec',
        owner: 'SE',
        documentId: 'SPEC-12',
        date: now.subtract(const Duration(days: 50)),
        y: 200,
        inputs: ['R-101'],
        outputs: ['D-5'],
      ),
      Artifact(
        id: 'D-5',
        name: 'Door Controller PCB',
        type: 'Design',
        owner: 'HW',
        documentId: 'DES-5',
        date: now.subtract(const Duration(days: 30)),
        y: 280,
        outputs: ['T-77'],
      ),
      Artifact(
        id: 'T-77',
        name: 'Locking integration test',
        type: 'Test',
        owner: 'QA',
        documentId: 'TEST-77',
        date: now.subtract(const Duration(days: 10)),
        y: 360,
      ),
      Artifact(
        id: 'RK-9',
        name: 'Hazard: unlock in motion',
        type: 'Risk',
        owner: 'RAMS',
        documentId: 'RISK-9',
        date: now.subtract(const Duration(days: 60)),
        y: 440,
      ),
    ]);
    links.addAll([
      Link(id: 'L1', fromId: 'R-101', toId: 'S-12', label: 'refines'),
      Link(id: 'L2', fromId: 'S-12', toId: 'D-5', label: 'implements'),
      Link(id: 'L3', fromId: 'D-5', toId: 'T-77', label: 'verifies'),
      Link(id: 'L4', fromId: 'RK-9', toId: 'S-12', label: 'mitigates in'),
    ]);
    bands.addAll([
      TimeBand(
        id: 'B1',
        label: 'Phase A',
        color: const Color(0xFF0EA5E9),
        type: 'Phase',
        start: now.subtract(const Duration(days: 75)),
        end: now.subtract(const Duration(days: 40)),
      ),
      TimeBand(
        id: 'B2',
        label: 'Phase B',
        color: const Color(0xFF22C55E),
        type: 'Phase',
        start: now.subtract(const Duration(days: 55)),
        end: now.subtract(const Duration(days: 5)),
      ),
      TimeBand(
        id: 'B3',
        label: 'Phase C',
        color: const Color(0xFFF59E0B),
        type: 'Phase',
        start: now.subtract(const Duration(days: 35)),
        end: now.add(const Duration(days: 10)),
      ),
    ]);
    events.addAll([
      TimeEvent(
        id: 'E1',
        label: 'SRR',
        type: 'Review',
        color: const Color(0xFF9333EA),
        date: now.subtract(const Duration(days: 60)),
      ),
      TimeEvent(
        id: 'E2',
        label: 'PDR',
        type: 'Review',
        color: const Color(0xFFDB2777),
        date: now.subtract(const Duration(days: 35)),
      ),
      TimeEvent(
        id: 'E3',
        label: 'CDR',
        type: 'Review',
        color: const Color(0xFF0EA5E9),
        date: now.subtract(const Duration(days: 12)),
      ),
      TimeEvent(
        id: 'E4',
        label: 'TRR',
        type: 'Review',
        color: const Color(0xFF22C55E),
        date: now.add(const Duration(days: 7)),
      ),
    ]);
    origin = DateTime(now.year, now.month - 3, now.day);
    endDate = now.add(const Duration(days: 30));
  }

  // ---------------- History ----------------
  String serialize() => jsonEncode({
    'title': timelineTitle,
    'subtitle': timelineSubtitle,
    'link': timelineLink,
    'origin': origin.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'pxPerDay': pxPerDay,
    'types': artifactTypes.map((t) => t.toJson()).toList(),
    'artifacts': artifacts.map((a) => a.toJson()).toList(),
    'links': links.map((l) => l.toJson()).toList(),
    'bands': bands.map((b) => b.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'people': people.map((p) => p.toJson()).toList(),
    'qualityGates': qualityGates.map((q) => q.toJson()).toList(),
    'globalTodos': globalTodos.map((t) => t.toJson()).toList(),
    'bandStackMode': bandStackMode,
    'bandOpacity': bandOpacity,
    'bandRowHeight': bandRowHeight,
    'bandRowGap': bandRowGap,
    'selectedBandIds': selectedBandIds.toList(),
    'selectedEventIds': selectedEventIds.toList(),
    'filterMode': filterMode.index,
    'typeFilter': typeFilter,
    'search': search,
    'dimFiltered': dimFiltered,
    'focusArtifactId': focusArtifactId,
    'focusDimOthers': focusDimOthers,
  });

  void restore(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    timelineTitle = map['title'] ?? kDefaultTimelineTitle;
    timelineSubtitle = map['subtitle'] ?? '';
    timelineLink = map['link'] ?? '';
    origin = DateTime.parse(map['origin']);
    endDate = DateTime.parse(map['endDate']);
    pxPerDay = (map['pxPerDay'] as num).toDouble();
    artifactTypes
      ..clear()
      ..addAll(
        ((map['types'] as List?) ?? []).map(
          (e) => ArtifactType.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    artifacts
      ..clear()
      ..addAll(
        ((map['artifacts'] as List?) ?? []).map(
          (e) => Artifact.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    links
      ..clear()
      ..addAll(
        ((map['links'] as List?) ?? []).map(
          (e) => Link.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    bands
      ..clear()
      ..addAll(
        ((map['bands'] as List?) ?? []).map(
          (e) => TimeBand.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    events
      ..clear()
      ..addAll(
        ((map['events'] as List?) ?? []).map(
          (e) => TimeEvent.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    people
      ..clear()
      ..addAll(
        ((map['people'] as List?) ?? []).map(
          (e) => Person.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    qualityGates
      ..clear()
      ..addAll(
        ((map['qualityGates'] as List?) ?? []).map(
          (e) => QualityGate.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    globalTodos
      ..clear()
      ..addAll(
        ((map['globalTodos'] as List?) ?? []).map(
          (e) => TodoItem.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    bandStackMode = map['bandStackMode'] ?? false;
    bandOpacity = (map['bandOpacity'] ?? 0.6).toDouble();
    bandRowHeight = (map['bandRowHeight'] ?? 22.0).toDouble();
    bandRowGap = (map['bandRowGap'] ?? 6.0).toDouble();
    selectedBandIds
      ..clear()
      ..addAll(
        ((map['selectedBandIds'] as List?) ?? []).map((e) => e.toString()),
      );
    selectedEventIds
      ..clear()
      ..addAll(
        ((map['selectedEventIds'] as List?) ?? []).map((e) => e.toString()),
      );
    filterMode = FilterMode.values[(map['filterMode'] ?? 0).toInt()];
    typeFilter = map['typeFilter'];
    search = map['search'] ?? '';
    dimFiltered = map['dimFiltered'] ?? false;

    focusArtifactId = map['focusArtifactId'];
    focusDimOthers = map['focusDimOthers'] ?? true;
    if (focusArtifactId != null) {
      final res = computeConnected(focusArtifactId!);
      focusedArtifactIds = res.$1;
      focusedLinkIds = res.$2;
    } else {
      focusedArtifactIds.clear();
      focusedLinkIds.clear();
    }
  }

  void pushHistory() {
    final snap = serialize();
    if (_historyIndex >= 0 && _historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(snap);
    _historyIndex = _history.length - 1;
    _syncActiveSlot(snap);
    _scheduleAutosave();
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    restore(_history[_historyIndex]);
    _syncActiveSlot(_history[_historyIndex]);
    _scheduleAutosave();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    restore(_history[_historyIndex]);
    _syncActiveSlot(_history[_historyIndex]);
    _scheduleAutosave();
    notifyListeners();
  }

  /// Imports a JSON snapshot from text and pushes the new state into history.
  void importJson(String jsonStr) {
    restore(jsonStr);
    pushHistory();
    notifyListeners();
  }

  // ---------------- Project management ----------------
  void _syncActiveSlot(String snap) {
    if (_projects.isEmpty) return;
    if (_currentProjectIndex < 0 ||
        _currentProjectIndex >= _projects.length) {
      return;
    }
    _projects[_currentProjectIndex]
      ..title = timelineTitle
      ..dataJson = snap;
  }

  void switchToProject(int index) {
    if (index == _currentProjectIndex) return;
    if (index < 0 || index >= _projects.length) return;
    // Make sure the slot we're leaving has the latest state cached.
    _syncActiveSlot(serialize());
    _currentProjectIndex = index;
    restore(_projects[index].dataJson);
    _history.clear();
    _historyIndex = -1;
    pushHistory();
    notifyListeners();
  }

  void addNewProject() {
    _syncActiveSlot(serialize());
    _resetToEmptyState();
    timelineTitle = _uniqueNewProjectTitle();
    _projects.add(_ProjectSlot(timelineTitle, serialize()));
    _currentProjectIndex = _projects.length - 1;
    _history.clear();
    _historyIndex = -1;
    pushHistory();
    notifyListeners();
  }

  void deleteCurrentProject() {
    if (!canDeleteCurrentProject) return;
    _projects.removeAt(_currentProjectIndex);
    if (_currentProjectIndex >= _projects.length) {
      _currentProjectIndex = _projects.length - 1;
    }
    restore(_projects[_currentProjectIndex].dataJson);
    _history.clear();
    _historyIndex = -1;
    pushHistory();
    notifyListeners();
  }

  String _uniqueNewProjectTitle() {
    final existing = _projects.map((p) => p.title).toSet();
    var n = _projects.length + 1;
    while (true) {
      final candidate = 'Projekt $n';
      if (!existing.contains(candidate)) return candidate;
      n++;
    }
  }

  void _resetToEmptyState() {
    final now = DateTime.now();
    artifacts.clear();
    links.clear();
    bands.clear();
    events.clear();
    people.clear();
    qualityGates.clear();
    globalTodos.clear();
    timelineSubtitle = '';
    timelineLink = '';
    artifactTypes
      ..clear()
      ..addAll([
        ArtifactType('Requirement', const Color(0xFF2563EB)),
        ArtifactType('Spec', const Color(0xFF7C3AED)),
        ArtifactType('Design', const Color(0xFF059669)),
        ArtifactType('Test', const Color(0xFFDC2626)),
        ArtifactType('Risk', const Color(0xFFEA580C)),
        ArtifactType('Doc', const Color(0xFF0EA5E9)),
      ]);
    origin = now.subtract(const Duration(days: 30));
    endDate = now.add(const Duration(days: 30));
    pxPerDay = 24;
    canvasHeight = 4000;
    bandStackMode = false;
    bandOpacity = 0.6;
    bandRowHeight = 22;
    bandRowGap = 6;
    typeFilter = null;
    artifactFilter = ArtifactFilter.none;
    search = '';
    dimFiltered = false;
    selectedBandIds.clear();
    selectedEventIds.clear();
    filterMode = FilterMode.ignore;
    focusArtifactId = null;
    focusDimOthers = true;
    focusedArtifactIds.clear();
    focusedLinkIds.clear();
    focusDepth = 1;
    linkMode = false;
    pendingLinkFromId = null;
    dragPosOverride.clear();
  }

  // ---------------- Autosave ----------------
  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounce, () {
      unawaited(persistNow());
    });
  }

  /// Writes the full session (projects + active index) to disk immediately.
  /// Awaitable so the shutdown button can guarantee the save lands before
  /// exit.
  Future<void> persistNow() async {
    _autosaveTimer?.cancel();
    final data = _currentSessionData();
    if (data == null) return;
    try {
      await writeSession(data);
    } catch (_) {
      // Best-effort; ignore disk failures so the UI keeps working.
    }
  }

  /// Writes a dated snapshot of the current session. Returns the absolute
  /// path on success, null if there's nothing to snapshot or the write
  /// fails.
  Future<String?> takeDailySnapshot() async {
    final data = _currentSessionData();
    if (data == null) return null;
    try {
      return await writeDailySnapshot(data);
    } catch (_) {
      return null;
    }
  }

  /// Replaces every project with the contents of [data]. The active slot is
  /// snapshotted into [_projects] first via [_currentSessionData] is *not*
  /// applicable here — we deliberately discard the in-memory state.
  void restoreFromSession(SessionData data) {
    if (data.projects.isEmpty) return;
    _projects
      ..clear()
      ..addAll(
        data.projects.map((p) => _ProjectSlot(p.title, p.dataJson)),
      );
    _currentProjectIndex = data.currentIndex.clamp(0, _projects.length - 1);
    restore(_projects[_currentProjectIndex].dataJson);
    _history.clear();
    _historyIndex = -1;
    pushHistory();
    notifyListeners();
  }

  SessionData? _currentSessionData() {
    _syncActiveSlot(serialize());
    if (_projects.isEmpty) return null;
    return SessionData(
      _currentProjectIndex,
      _projects
          .map((p) => SessionProject(p.title, p.dataJson))
          .toList(growable: false),
      basePath: basePath,
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  // ---------------- Coordinate helpers ----------------
  ArtifactType typeByKey(String key) => artifactTypes.firstWhere(
    (t) => t.key == key,
    orElse: () => ArtifactType('Other', const Color(0xFF64748B)),
  );

  double xForDate(DateTime d) => d.difference(origin).inDays * pxPerDay + 140;

  DateTime dateForX(double x) {
    final days = ((x - 140) / pxPerDay).round();
    return origin.add(Duration(days: days));
  }

  Offset? positionOfId(String id, {int depth = 0}) {
    final Artifact? a = artifacts.firstWhereOrNull((x) => x.id == id);
    if (a != null) {
      final override = dragPosOverride[id];
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

  // ---------------- Focus ----------------
  void setFocus(String? id) {
    focusArtifactId = id;
    if (id == null) {
      focusedArtifactIds.clear();
      focusedLinkIds.clear();
    } else {
      final res = computeConnected(id, maxDepth: focusDepth);
      focusedArtifactIds = res.$1;
      focusedLinkIds = res.$2;
    }
    notifyListeners();
    pushHistory();
  }

  void toggleFocusDimOthers() {
    focusDimOthers = !focusDimOthers;
    notifyListeners();
    pushHistory();
  }

  void setFocusDepth(int depth) {
    focusDepth = depth;
    if (focusArtifactId != null) {
      final res = computeConnected(focusArtifactId!, maxDepth: focusDepth);
      focusedArtifactIds = res.$1;
      focusedLinkIds = res.$2;
    }
    notifyListeners();
    pushHistory();
  }

  (Set<String>, Set<String>) computeConnected(
    String startId, {
    int maxDepth = 1,
  }) {
    final artSet = <String>{startId};
    final linkSet = <String>{};
    final q = <(String, int)>[(startId, 0)];

    final byFrom = <String, List<Link>>{};
    final byTo = <String, List<Link>>{};
    for (final l in links) {
      (byFrom[l.fromId] ??= []).add(l);
      (byTo[l.toId] ??= []).add(l);
    }

    while (q.isNotEmpty) {
      final (cur, depth) = q.removeAt(0);
      if (depth >= maxDepth) continue;

      for (final l in byFrom[cur] ?? const []) {
        linkSet.add(l.id);
        if (artSet.add(l.toId)) q.add((l.toId, depth + 1));
      }
      for (final l in byTo[cur] ?? const []) {
        linkSet.add(l.id);
        if (artSet.add(l.fromId)) q.add((l.fromId, depth + 1));
      }
    }
    return (artSet, linkSet);
  }

  // ---------------- Link IO helpers ----------------
  List<String> inboundOf(String id) => links
      .where((l) => l.toId == id && artifacts.any((a) => a.id == l.fromId))
      .map((l) => l.fromId)
      .toList();

  List<String> outboundOf(String id) => links
      .where((l) => l.fromId == id && artifacts.any((a) => a.id == l.toId))
      .map((l) => l.toId)
      .toList();

  void applyIOSelections(
    Artifact a,
    Set<String> inbound,
    Set<String> outbound,
  ) {
    for (final l in links
        .where((l) => l.toId == a.id && !inbound.contains(l.fromId))
        .toList()) {
      links.remove(l);
    }
    for (final l in links
        .where((l) => l.fromId == a.id && !outbound.contains(l.toId))
        .toList()) {
      links.remove(l);
    }
    for (final from in inbound) {
      if (!links.any((l) => l.fromId == from && l.toId == a.id)) {
        links.add(
          Link(
            id: 'L${DateTime.now().microsecondsSinceEpoch}${from.hashCode}',
            fromId: from,
            toId: a.id,
          ),
        );
      }
    }
    for (final to in outbound) {
      if (!links.any((l) => l.fromId == a.id && l.toId == to)) {
        links.add(
          Link(
            id: 'L${DateTime.now().microsecondsSinceEpoch}${to.hashCode}',
            fromId: a.id,
            toId: to,
          ),
        );
      }
    }
    a.inputs = inbound.toList();
    a.outputs = outbound.toList();
  }

  // ---------------- Filter predicates ----------------
  bool passesMembershipFilters(Artifact a) {
    if (filterMode == FilterMode.ignore) return true;
    final inBands = a.bandIds.any(selectedBandIds.contains);
    final inEvents = a.eventIds.any(selectedEventIds.contains);
    final isSelected =
        (selectedBandIds.isNotEmpty && inBands) ||
        (selectedEventIds.isNotEmpty && inEvents);
    if (filterMode == FilterMode.showOnly) {
      final hasAnyCriterion =
          selectedBandIds.isNotEmpty || selectedEventIds.isNotEmpty;
      return !hasAnyCriterion || isSelected;
    } else if (filterMode == FilterMode.hideSelected) {
      return !isSelected;
    }
    return true;
  }

  bool visibleArtifact(Artifact a) {
    final typeOk = typeFilter == null || a.type == typeFilter;
    final qgText = a.qualityGateIds.map(qualityGateName).join(' ');
    final text = '${a.name} ${a.owner} ${a.documentId} $qgText'.toLowerCase();
    final searchOk = search.isEmpty || text.contains(search.toLowerCase());
    bool filterOk = true;
    switch (artifactFilter) {
      case ArtifactFilter.none:
        filterOk = true;
        break;
      case ArtifactFilter.unlinked:
        filterOk = !links.any((l) => l.fromId == a.id || l.toId == a.id);
        break;
      case ArtifactFilter.liegtVorOff:
        filterOk = a.liegtVor == false;
        break;
      case ArtifactFilter.klarOff:
        filterOk = a.klar == false;
        break;
    }

    final membershipOk = passesMembershipFilters(a);
    final inYearWindow = !a.date.isBefore(origin) && !a.date.isAfter(endDate);

    if (focusArtifactId != null && !focusedArtifactIds.contains(a.id)) {
      if (focusDimOthers) {
        // allowed, will be dimmed in UI
      } else {
        return false;
      }
    }
    return typeOk && searchOk && filterOk && membershipOk && inYearWindow;
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
    if (focusArtifactId != null && !focusedLinkIds.contains(l.id)) {
      if (focusDimOthers) {
        return true;
      } else {
        return false;
      }
    }
    return true;
  }

  List<Artifact> get artifactsToDraw =>
      dimFiltered ? artifacts : artifacts.where(visibleArtifact).toList();
  List<Link> get linksToDraw =>
      dimFiltered ? links : links.where(visibleLink).toList();

  // ---------------- Link mode ----------------
  void toggleLinkMode() {
    linkMode = !linkMode;
    if (!linkMode) pendingLinkFromId = null;
    notifyListeners();
  }

  /// Click on an artifact/link node while in link mode. Returns true if a new
  /// link was created (caller can push history, though we already do).
  void handleLinkModeClick(String nodeId) {
    if (pendingLinkFromId == null) {
      pendingLinkFromId = nodeId;
      notifyListeners();
      return;
    }
    if (pendingLinkFromId == nodeId) {
      pendingLinkFromId = null;
      notifyListeners();
      return;
    }
    links.add(
      Link(
        id: 'L${DateTime.now().microsecondsSinceEpoch}',
        fromId: pendingLinkFromId!,
        toId: nodeId,
      ),
    );
    pendingLinkFromId = null;
    linkMode = false;
    notifyListeners();
    pushHistory();
  }

  // ---------------- Drag ----------------
  void startDrag(String id, Offset basePos) {
    dragPosOverride[id] = basePos;
    notifyListeners();
  }

  void updateDrag(String id, Offset next) {
    dragPosOverride[id] = next;
    notifyListeners();
  }

  void endDrag(Artifact a, Offset endPos) {
    a.date = dateForX(endPos.dx);
    a.y = endPos.dy;
    dragPosOverride.remove(a.id);
    notifyListeners();
    pushHistory();
  }

  // ---------------- Mutations used by dialogs ----------------
  void addArtifact(Artifact a, Set<String> inbound, Set<String> outbound) {
    artifacts.add(a);
    applyIOSelections(a, inbound, outbound);
    notifyListeners();
    pushHistory();
  }

  void deleteArtifact(Artifact a) {
    artifacts.removeWhere((x) => x.id == a.id);
    links.removeWhere((l) => l.fromId == a.id || l.toId == a.id);
    if (focusArtifactId == a.id) {
      focusArtifactId = null;
      focusedArtifactIds.clear();
      focusedLinkIds.clear();
    }
    notifyListeners();
    pushHistory();
  }

  void deleteLink(Link l) {
    links.remove(l);
    notifyListeners();
    pushHistory();
  }

  void setTimelineTitle(String title) {
    timelineTitle = title.trim().isEmpty ? kDefaultTimelineTitle : title.trim();
    notifyListeners();
    pushHistory();
  }

  void setTimelineSubtitle(String subtitle) {
    final next = subtitle.trim();
    if (timelineSubtitle == next) return;
    timelineSubtitle = next;
    notifyListeners();
    pushHistory();
  }

  void setTimelineLink(String link) {
    final next = link.trim();
    if (timelineLink == next) return;
    timelineLink = next;
    notifyListeners();
    pushHistory();
  }

  /// Name of a quality gate by id, or '' when unknown.
  String qualityGateName(String id) =>
      qualityGates.firstWhereOrNull((q) => q.id == id)?.name ?? '';

  /// Distinct, non-empty person names — feeds the owner/assignee
  /// auto-suggest.
  List<String> get personNames {
    final seen = <String>{};
    final out = <String>[];
    for (final p in people) {
      final n = p.name.trim();
      if (n.isNotEmpty && seen.add(n.toLowerCase())) out.add(n);
    }
    return out;
  }

  void setTimeRange(DateTime start, DateTime end) {
    origin = start;
    endDate = end;
    notifyListeners();
    pushHistory();
  }

  void setPxPerDay(double v) {
    pxPerDay = v;
    notifyListeners();
  }

  void setTypeFilter(String? v) {
    typeFilter = v;
    notifyListeners();
  }

  void setArtifactFilter(ArtifactFilter v) {
    artifactFilter = v;
    notifyListeners();
    pushHistory();
  }

  void setDimFiltered(bool v) {
    dimFiltered = v;
    notifyListeners();
  }

  void setSearch(String v) {
    search = v;
    notifyListeners();
  }

  void applyBandLayout({
    required bool stack,
    required double opacity,
    required double rowH,
    required double rowG,
  }) {
    bandStackMode = stack;
    bandOpacity = opacity;
    bandRowHeight = rowH;
    bandRowGap = rowG;
    notifyListeners();
    pushHistory();
  }

  void applyFilters({
    required Set<String> bands,
    required Set<String> events,
    required FilterMode mode,
  }) {
    selectedBandIds
      ..clear()
      ..addAll(bands);
    selectedEventIds
      ..clear()
      ..addAll(events);
    filterMode = mode;
    notifyListeners();
    pushHistory();
  }
}
