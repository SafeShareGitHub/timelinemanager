import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timelinemanager/classes/artifact.dart';
import 'package:timelinemanager/classes/link.dart';
import 'package:timelinemanager/classes/timeEvent.dart';
import 'package:timelinemanager/classes/timeband.dart';
import 'package:timelinemanager/main.dart';

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
    final gridPaint = Paint()
      ..color = const Color(0x11000000)
      ..strokeWidth = 1;
    final monthPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 2;

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
        _text(
          canvas,
          '${iter.year}-${iter.month.toString().padLeft(2, '0')}',
          Offset(x + 4, 0),
          12,
          const Color(0x88000000),
        );
      } else {
        canvas.drawLine(Offset(x, 28), Offset(x, size.height - 40), gridPaint);
      }
      if (i % 7 == 0) {
        _text(
          canvas,
          '${iter.month}/${iter.day}',
          Offset(x + 2, 28),
          10,
          const Color(0x66000000),
        );
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
          final paint = Paint()
            ..color = b.color.withOpacity(bandOpacity.clamp(0.0, 1.0));
          canvas.drawRRect(r, paint);
          _text(canvas, b.label, Offset(sX + 6, bandTop + 2), 11, Colors.white);
        }
      } else {
        final assigned = _assignBandLanes(bands);
        final laneCount = assigned.values.fold<int>(
          0,
          (maxL, lane) => math.max(maxL, lane + 1),
        );
        final totalHeight =
            laneCount * bandRowHeight + (laneCount - 1) * bandRowGap;
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
          _text(
            canvas,
            b.label,
            Offset(sX + 6, top + (bandRowHeight - 14) / 2),
            11,
            Colors.white,
          );
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
        canvas.drawLine(
          Offset(x, topY),
          Offset(x, topY + stemH),
          Paint()
            ..color = e.color.withOpacity(0.85)
            ..strokeWidth = 2,
        );

        // pin head (circle)
        canvas.drawCircle(
          Offset(x, topY),
          circleR,
          Paint()..color = e.color.withOpacity(0.95),
        );

        // label bubble
        final label = e.label;
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + 6,
            topY - tp.height - 4,
            tp.width + 10,
            tp.height + 6,
          ),
          const Radius.circular(6),
        );
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
      final path = Path()
        ..moveTo(pFrom.dx, pFrom.dy)
        ..cubicTo(midX, pFrom.dy, midX, pTo.dy, pTo.dx, pTo.dy);

      final fromArt = allArtifacts.firstWhereOrNull((a) => a.id == l.fromId);
      final baseColor = fromArt != null
          ? typeByKey(fromArt.type).color
          : const Color(0xFF475569);
      double baseOpacity = globallyVisible ? 0.9 : 0.18;
      if (focusArtifactId != null && !inFocus && focusDimOthers) {
        baseOpacity = baseOpacity * 0.22;
      }
      final color = baseColor.withOpacity(baseOpacity.clamp(0.0, 1.0));
      final glowAlpha = globallyVisible ? 0.22 : 0.06;
      final glow = Paint()
        ..color = color.withOpacity(glowAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      final pen = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      canvas.drawPath(path, glow);
      canvas.drawPath(path, pen);
      _arrowHead(canvas, Offset(pTo.dx, pTo.dy), Offset(midX, pTo.dy), color);
    }

    _text(
      canvas,
      'Zeitachse (Tage)',
      Offset(12, size.height - 22),
      12,
      const Color(0x88000000),
    );
  }

  Map<String, int> _assignBandLanes(List<TimeBand> items) {
    final sorted = [...items]
      ..sort((a, b) {
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
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - s * math.cos(ang - math.pi / 6),
        tip.dy - s * math.sin(ang - math.pi / 6),
      )
      ..lineTo(
        tip.dx - s * math.cos(ang + math.pi / 6),
        tip.dy - s * math.sin(ang + math.pi / 6),
      )
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _text(Canvas c, String s, Offset o, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant TimelinePainter old) => true;
}
