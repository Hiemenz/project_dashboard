import 'package:flutter/material.dart';

import 'dashboard_screen.dart';

void main() {
  runApp(const PiDashboardApp());
}

class PiDashboardApp extends StatelessWidget {
  const PiDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pi Dashboard',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
