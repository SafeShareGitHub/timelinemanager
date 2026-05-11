export 'session_store_io.dart' if (dart.library.html) 'session_store_web.dart';

/// One saved project inside the session file. [dataJson] is the same string
/// [TimelineController.serialize] produces, kept opaque here so this layer
/// doesn't need to know the timeline schema.
class SessionProject {
  final String title;
  final String dataJson;
  const SessionProject(this.title, this.dataJson);

  Map<String, dynamic> toJson() => {'title': title, 'data': dataJson};
  factory SessionProject.fromJson(Map<String, dynamic> j) =>
      SessionProject(j['title'] as String, j['data'] as String);
}

/// Everything we restore on app boot: the project list and which one was
/// active. Stored on disk at the platform-specific session path.
class SessionData {
  final int currentIndex;
  final List<SessionProject> projects;
  const SessionData(this.currentIndex, this.projects);
}

/// A discovered snapshot file on disk. Returned by `listSnapshots()` so the
/// restore dialog can show the user what's available.
class SnapshotEntry {
  final String path;
  final String name;
  final DateTime modified;
  final int projectCount;
  const SnapshotEntry({
    required this.path,
    required this.name,
    required this.modified,
    required this.projectCount,
  });
}
