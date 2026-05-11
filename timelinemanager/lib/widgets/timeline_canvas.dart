import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/timelinePainter.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/widgets/artifact_node.dart';
import 'package:timelinemanager/widgets/link_label.dart';

class TimelineCanvas extends StatelessWidget {
  final TimelineController controller;
  const TimelineCanvas({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final daysRange = c.endDate.difference(c.origin).inDays.abs().clamp(1, 10000);
    final canvasWidth = 140 + daysRange * c.pxPerDay + 200;

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 2.5,
      constrained: false,
      child: SizedBox(
        width: canvasWidth,
        height: c.canvasHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: TimelinePainter(
                  origin: c.origin,
                  endDate: c.endDate,
                  pxPerDay: c.pxPerDay,
                  artifacts: c.artifactsToDraw,
                  links: c.linksToDraw,
                  typeByKey: c.typeByKey,
                  posOfId: c.positionOfId,
                  dimMode: c.dimFiltered,
                  allArtifacts: c.artifacts,
                  allLinks: c.links,
                  isArtifactVisible: c.visibleArtifact,
                  isLinkVisible: c.visibleLink,
                  bands: c.bands,
                  events: c.events,
                  bandStackMode: c.bandStackMode,
                  bandOpacity: c.bandOpacity,
                  bandRowHeight: c.bandRowHeight,
                  bandRowGap: c.bandRowGap,
                  focusArtifactId: c.focusArtifactId,
                  focusedLinkIds: c.focusedLinkIds,
                  focusDimOthers: c.focusDimOthers,
                ),
              ),
            ),
            if (c.linkMode)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ...c.links
                .where((l) => c.dimFiltered ? true : c.visibleLink(l))
                .map((l) => LinkLabel(controller: c, link: l)),
            ...c.artifacts.map(
              (a) => ArtifactNode(controller: c, artifact: a),
            ),
          ],
        ),
      ),
    );
  }
}
