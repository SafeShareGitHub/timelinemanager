import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/link.dart';
import 'package:timelinemanager/dialogues/editlink.dart';
import 'package:timelinemanager/state/timeline_controller.dart';

class LinkLabel extends StatelessWidget {
  final TimelineController controller;
  final Link link;

  const LinkLabel({super.key, required this.controller, required this.link});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final l = link;
    final pos = c.positionOfId(l.id);
    if (pos == null) return const SizedBox.shrink();

    final inFocus =
        c.focusArtifactId == null || c.focusedLinkIds.contains(l.id);
    final baseVisible = c.visibleLink(l);
    final opacityFocus =
        (c.focusArtifactId != null && !inFocus && c.focusDimOthers)
            ? 0.18
            : 1.0;
    final opacityFiltered = (c.dimFiltered && !baseVisible) ? 0.25 : 1.0;
    final combinedOpacity = (opacityFocus * opacityFiltered).clamp(0.0, 1.0);

    return Positioned(
      left: pos.dx - 70,
      top: pos.dy - 40,
      child: Opacity(
        opacity: combinedOpacity,
        child: GestureDetector(
          onTap: () {
            if (!c.linkMode) return;
            c.handleLinkModeClick(l.id);
          },
          onDoubleTap: () => showEditLinkDialog(context, c, l),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Color(0x22000000)),
              ],
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 14),
                const SizedBox(width: 6),
                Text(
                  l.label.isEmpty ? l.id : l.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
