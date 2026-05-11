import 'package:flutter/material.dart';
import 'package:timelinemanager/platform/lifecycle.dart';
import 'package:timelinemanager/state/timeline_controller.dart';
import 'package:timelinemanager/widgets/legend_bar.dart';
import 'package:timelinemanager/widgets/timeline_app_bar.dart';
import 'package:timelinemanager/widgets/timeline_canvas.dart';
import 'package:timelinemanager/widgets/timeline_toolbar.dart';

class TimelineHome extends StatefulWidget {
  const TimelineHome({super.key});

  @override
  State<TimelineHome> createState() => _TimelineHomeState();
}

class _TimelineHomeState extends State<TimelineHome> {
  final TimelineController _controller = TimelineController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    installBeforeUnloadGuard();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TimelineAppBar(controller: _controller),
      body: Column(
        children: [
          TimelineToolbar(controller: _controller),
          const SizedBox(height: 8),
          Expanded(child: TimelineCanvas(controller: _controller)),
          LegendBar(controller: _controller),
        ],
      ),
    );
  }
}
