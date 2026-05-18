import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:timelinemanager/dialogues/JSONexport.dart';
import 'package:timelinemanager/dialogues/JSONimport.dart';
import 'package:timelinemanager/dialogues/bandlayout.dart';
import 'package:timelinemanager/dialogues/filter.dart';
import 'package:timelinemanager/dialogues/focusdepth.dart';
import 'package:timelinemanager/dialogues/managebands.dart';
import 'package:timelinemanager/dialogues/manageevents.dart';
import 'package:timelinemanager/dialogues/managequalitygates.dart';
import 'package:timelinemanager/dialogues/managetypes.dart';
import 'package:timelinemanager/dialogues/organigramm.dart';
import 'package:timelinemanager/dialogues/sessionrestore.dart';
import 'package:timelinemanager/dialogues/settings.dart';
import 'package:timelinemanager/dialogues/yearfilter.dart';
import 'package:timelinemanager/platform/external_open.dart';
import 'package:timelinemanager/platform/session_store.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

const int _kMenuNewProject = -1;
const int _kMenuDeleteProject = -2;

class TimelineAppBar extends StatefulWidget implements PreferredSizeWidget {
  final TimelineController controller;

  const TimelineAppBar({super.key, required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<TimelineAppBar> createState() => _TimelineAppBarState();
}

class _TimelineAppBarState extends State<TimelineAppBar> {
  bool _isEditingTitle = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final FocusNode _subtitleFocus = FocusNode();

  TimelineController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _subtitleController.text = c.timelineSubtitle;
    _subtitleFocus.addListener(_onSubtitleFocusChange);
  }

  @override
  void dispose() {
    _subtitleFocus.removeListener(_onSubtitleFocusChange);
    _subtitleFocus.dispose();
    _subtitleController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Persist the subtitle when the field loses focus.
  void _onSubtitleFocusChange() {
    if (!_subtitleFocus.hasFocus) {
      c.setTimelineSubtitle(_subtitleController.text);
    }
  }

  void _commitTitle(String value) {
    c.setTimelineTitle(value);
    setState(() => _isEditingTitle = false);
  }

  void _copySubtitle() {
    final text = _subtitleController.text.trim();
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text.isEmpty
              ? 'Zweite Überschrift ist leer.'
              : 'In Zwischenablage kopiert: $text',
        ),
      ),
    );
  }

  /// Opens the stored web link directly, no dialog.
  Future<void> _openLink() async {
    final url = c.timelineLink.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein Web-Link hinterlegt.')),
      );
      return;
    }
    final result = await openUrlExternally(url);
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error ?? 'Link konnte nicht geöffnet werden.',
          ),
        ),
      );
    }
  }

  /// Dialog to edit and save the stored web link.
  Future<void> _editLink() async {
    final linkC = TextEditingController(text: c.timelineLink);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Web-Link bearbeiten'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: linkC,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              c.setTimelineLink(linkC.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleProjectMenu(int action) async {
    if (action == _kMenuNewProject) {
      c.addNewProject();
      return;
    }
    if (action == _kMenuDeleteProject) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Projekt löschen?'),
          content: Text(
            'Das Projekt „${c.projectTitles[c.currentProjectIndex]}" '
            'wird unwiderruflich gelöscht.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen'),
            ),
          ],
        ),
      );
      if (confirmed == true) c.deleteCurrentProject();
      return;
    }
    c.switchToProject(action);
  }

  Future<void> _handleShutdown() async {
    await c.persistNow();
    if (!mounted) return;
    quitApp();
  }

  Future<void> _handleSnapshot() async {
    final path = await c.takeDailySnapshot();
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot fehlgeschlagen.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Snapshot gespeichert: $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the subtitle field in sync with external changes (project
    // switch, undo/redo) without clobbering an active edit.
    if (!_subtitleFocus.hasFocus &&
        _subtitleController.text != c.timelineSubtitle) {
      _subtitleController.text = c.timelineSubtitle;
    }
    final hasLink = c.timelineLink.trim().isNotEmpty;
    // Match the subtitle field to the AppBar's title typography so both
    // heading parts read as one line.
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    return AppBar(
      titleSpacing: 8,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ---- First part: project / title ----
          Flexible(
            flex: 5,
            child: _isEditingTitle
                ? TextField(
                    controller: _titleController..text = c.timelineTitle,
                    autofocus: true,
                    style: titleStyle,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: _commitTitle,
                  )
                : _buildProjectSelector(),
          ),
          IconButton(
            tooltip: _isEditingTitle ? 'Titel speichern' : 'Titel bearbeiten',
            icon: Icon(_isEditingTitle ? Icons.check : Icons.edit, size: 20),
            onPressed: () {
              if (_isEditingTitle) {
                _commitTitle(_titleController.text);
              } else {
                setState(() {
                  _titleController.text = c.timelineTitle;
                  _isEditingTitle = true;
                });
              }
            },
          ),
          // ---- fixed separator ----
          // Integer width keeps the vertical line crisp; a fractional
          // width renders blurry and visually off-centre.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 2,
              height: 28,
              color: Theme.of(context).dividerColor,
            ),
          ),
          // ---- Second part: free-text subtitle + copy + web link ----
          Flexible(
            flex: 5,
            child: TextField(
              controller: _subtitleController,
              focusNode: _subtitleFocus,
              style: titleStyle,
              // Force the field's line metric to the text style so its
              // baseline matches a plain Text widget (the first heading).
              strutStyle: StrutStyle.fromTextStyle(
                titleStyle ?? const TextStyle(),
                forceStrutHeight: true,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Zweite Überschrift',
              ),
              onSubmitted: c.setTimelineSubtitle,
            ),
          ),
          IconButton(
            tooltip: 'Zweite Überschrift in Zwischenablage kopieren',
            icon: const Icon(Icons.content_copy, size: 20),
            onPressed: _copySubtitle,
          ),
          IconButton(
            tooltip: 'Web-Link öffnen',
            icon: Icon(
              Icons.public,
              size: 22,
              color: hasLink ? Colors.lightBlueAccent : null,
            ),
            onPressed: hasLink ? _openLink : null,
          ),
          IconButton(
            tooltip: 'Web-Link bearbeiten',
            icon: const Icon(Icons.edit, size: 20),
            onPressed: _editLink,
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Organigramm',
          onPressed: () => showOrganigrammDialog(context, c),
          icon: const Icon(Icons.groups_outlined),
        ),
        IconButton(
          tooltip: 'Quality Gates',
          onPressed: () => showManageQualityGatesDialog(context, c),
          icon: const Icon(Icons.verified_outlined),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Undo',
          onPressed: c.canUndo ? c.undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Redo',
          onPressed: c.canRedo ? c.redo : null,
          icon: const Icon(Icons.redo),
        ),
        IconButton(
          tooltip: 'Typen verwalten',
          onPressed: () => showManageTypesDialog(context, c),
          icon: const Icon(Icons.category_outlined),
        ),
        IconButton(
          tooltip: 'Zeit-Bänder',
          onPressed: () => showManageBandsDialog(context, c),
          icon: const Icon(Icons.label_outline),
        ),
        IconButton(
          tooltip: 'Events',
          onPressed: () => showManageEventsDialog(context, c),
          icon: const Icon(Icons.push_pin_outlined),
        ),
        IconButton(
          tooltip: 'Band-Layout',
          onPressed: () => showBandLayoutDialog(context, c),
          icon: const Icon(Icons.movie_creation_outlined),
        ),
        IconButton(
          tooltip: 'Filter (Phasen/Events)',
          onPressed: () => showPhaseEventFilterDialog(context, c),
          icon: const Icon(Icons.filter_alt_outlined),
        ),
        IconButton(
          tooltip: 'Jahresfilter',
          onPressed: () => showYearFilterDialog(context, c),
          icon: const Icon(Icons.calendar_month_outlined),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Fokus-Tiefe einstellen',
          onPressed: () => showFocusDepthDialog(context, c),
          icon: const Icon(Icons.settings_input_component),
        ),
        IconButton(
          tooltip: 'Fokus löschen',
          onPressed: c.focusArtifactId != null ? () => c.setFocus(null) : null,
          icon: const Icon(Icons.highlight_off),
        ),
        IconButton(
          tooltip: c.focusDimOthers ? 'Fokus: Dimmen' : 'Fokus: Ausblenden',
          onPressed:
              c.focusArtifactId != null ? c.toggleFocusDimOthers : null,
          icon: Icon(c.focusDimOthers ? Icons.tonality : Icons.visibility_off),
        ),
        IconButton(
          tooltip: 'Export JSON',
          onPressed: () => exportTimelineToJson(context, c),
          icon: const Icon(Icons.download),
        ),
        IconButton(
          tooltip: 'Import JSON',
          onPressed: () => showJsonImportDialog(context, c),
          icon: const Icon(Icons.upload),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Einstellungen',
          onPressed: () => showSettingsDialog(context, c),
          icon: const Icon(Icons.settings),
        ),
        IconButton(
          tooltip: 'Snapshot von heute speichern',
          onPressed:
              kSessionPersistenceSupported ? _handleSnapshot : null,
          icon: const Icon(Icons.save_alt),
        ),
        IconButton(
          tooltip: 'Sitzung wiederherstellen…',
          onPressed: () => showSessionRestoreDialog(context, c),
          icon: const Icon(Icons.restore),
        ),
        IconButton(
          tooltip: kSessionPersistenceSupported
              ? 'Sitzung speichern & beenden'
              : 'Beenden',
          onPressed: _handleShutdown,
          icon: const Icon(Icons.power_settings_new),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProjectSelector() {
    final titles = c.projectTitles;
    final currentIndex = c.currentProjectIndex;
    return PopupMenuButton<int>(
      tooltip: 'Projekt wechseln',
      onSelected: _handleProjectMenu,
      itemBuilder: (ctx) => [
        for (var i = 0; i < titles.length; i++)
          CheckedPopupMenuItem<int>(
            value: i,
            checked: i == currentIndex,
            child: Text(
              titles[i],
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<int>(
          value: _kMenuNewProject,
          child: Row(
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('Neues Projekt'),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: _kMenuDeleteProject,
          enabled: c.canDeleteCurrentProject,
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 18),
              SizedBox(width: 8),
              Text('Aktuelles Projekt löschen'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              c.timelineTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
