import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/dialogues/editartifact.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

class ArtifactNode extends StatelessWidget {
  final TimelineController controller;
  final Artifact artifact;

  const ArtifactNode({
    super.key,
    required this.controller,
    required this.artifact,
  });

  Future<void> _showContextMenu(
    BuildContext context,
    TimelineController c,
    Artifact a,
    Offset globalPosition,
  ) async {
    final files = a.linkedFiles
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        if (files.isEmpty)
          const PopupMenuItem(
            value: 'open',
            enabled: false,
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 18),
                SizedBox(width: 8),
                Text('Datei öffnen (keine verknüpft)'),
              ],
            ),
          )
        else
          for (var i = 0; i < files.length; i++)
            PopupMenuItem(
              value: 'open:$i',
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Öffnen: ${_basename(files[i])}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Bearbeiten'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'focus',
          child: Row(
            children: [
              Icon(Icons.center_focus_strong, size: 18),
              SizedBox(width: 8),
              Text('Fokus umschalten'),
            ],
          ),
        ),
      ],
    );
    if (selected == null) return;
    if (selected.startsWith('open:')) {
      final i = int.tryParse(selected.substring('open:'.length)) ?? -1;
      if (i < 0 || i >= files.length) return;
      final result = await c.openArtifactFile(files[i]);
      if (!context.mounted) return;
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Öffnen fehlgeschlagen.')),
        );
      }
    } else if (selected == 'edit') {
      if (!context.mounted) return;
      showEditArtifactDialog(context, c, a);
    } else if (selected == 'focus') {
      c.setFocus(c.focusArtifactId == a.id ? null : a.id);
    }
  }

  static String _basename(String path) {
    final cleaned = path.replaceAll('"', '');
    final parts = cleaned.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? cleaned : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final a = artifact;
    final isVis = c.visibleArtifact(a);
    if (!c.dimFiltered && !isVis) return const SizedBox.shrink();

    final basePos = Offset(c.xForDate(a.date), a.y);
    final pos = c.dragPosOverride[a.id] ?? basePos;
    final t = c.typeByKey(a.type);
    final selected = c.linkMode && c.pendingLinkFromId == a.id;

    final inFocus =
        c.focusArtifactId == null || c.focusedArtifactIds.contains(a.id);
    final focusOpacity =
        (c.focusArtifactId != null && !inFocus && c.focusDimOthers) ? 0.22 : 1.0;
    final filteredOpacity = c.dimFiltered && !isVis ? 0.25 : 1.0;
    final opacity = (focusOpacity * filteredOpacity).clamp(0.0, 1.0);

    return Positioned(
      left: pos.dx - 70,
      top: pos.dy - 22,
      child: GestureDetector(
        onTap: () {
          if (!c.linkMode) return;
          c.handleLinkModeClick(a.id);
        },
        onLongPress: () {
          c.setFocus(c.focusArtifactId == a.id ? null : a.id);
        },
        onDoubleTap: () => showEditArtifactDialog(context, c, a),
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, c, a, details.globalPosition),
        onPanStart: (_) => c.startDrag(a.id, basePos),
        onPanUpdate: (d) {
          final prev = c.dragPosOverride[a.id] ?? basePos;
          final next = Offset(
            prev.dx + d.delta.dx,
            (prev.dy + d.delta.dy).clamp(60, c.canvasHeight - 40),
          );
          c.updateDrag(a.id, next);
        },
        onPanEnd: (_) {
          final endPos = c.dragPosOverride[a.id] ?? basePos;
          c.endDrag(a, endPos);
        },
        child: Opacity(
          opacity: opacity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? t.color.withOpacity(0.95)
                  : t.color.withOpacity(0.88),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 6,
                  offset: Offset(0, 2),
                  color: Color(0x22000000),
                ),
              ],
              border: Border.all(
                color: c.focusArtifactId == a.id
                    ? Colors.yellowAccent
                    : Colors.white,
                width: c.focusArtifactId == a.id ? 2.2 : 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      a.owner.isEmpty ? '' : a.owner,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                    if (a.documentId.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        a.documentId,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
