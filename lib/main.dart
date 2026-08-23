import 'package:flutter/material.dart';

import 'data/gnss_service.dart';
import 'ui/dashboard_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(const GroundspeedApp());
}

class GroundspeedApp extends StatelessWidget {
  const GroundspeedApp({super.key, this.service});

  /// Injectable so widget tests can run without platform plugins.
  final GnssService? service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Groundspeed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GsColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GsColors.accent,
          brightness: Brightness.dark,
        ),
      ),
      home: DashboardScreen(service: service ?? GnssService()),
    );
  }
}
