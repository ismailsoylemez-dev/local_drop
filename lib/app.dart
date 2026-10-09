import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'ui/screens/home_screen.dart';

class LocalDropApp extends StatelessWidget {
  const LocalDropApp({super.key});

  static const Color _seed = Colors.teal;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
