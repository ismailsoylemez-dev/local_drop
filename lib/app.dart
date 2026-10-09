import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'state/server_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';

class LocalDropApp extends StatelessWidget {
  const LocalDropApp({super.key});

  static const Color _seed = Colors.teal;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<ServerController, ThemeMode>(
      (c) => c.themeMode,
    );
    final onboardingDone = context.select<ServerController, bool>(
      (c) => c.onboardingDone,
    );

    return MaterialApp(
      title: AppConstants.appTitle,
      themeMode: themeMode,
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
      home: onboardingDone ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
