import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/server_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServerController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sunucu kapalı', style: textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.start,
              child: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }
}
