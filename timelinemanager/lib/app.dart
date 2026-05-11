import 'package:flutter/material.dart';
import 'package:timelinemanager/screens/timeline_home.dart';

class TraceabilityApp extends StatelessWidget {
  const TraceabilityApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Timeline Traceability',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: const TimelineHome(),
  );
}
