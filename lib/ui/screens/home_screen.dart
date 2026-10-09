import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/network_service.dart';
import '../../state/server_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServerController>();
    final textTheme = Theme.of(context).textTheme;
    final networkText = switch (controller.network) {
      null => 'Ağ kontrol ediliyor…',
      Connected(:final ip) => 'IP: $ip',
      NoNetwork() => 'Ağ bağlantısı yok',
    };

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sunucu kapalı', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(networkText, style: textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.canStart ? controller.start : null,
              child: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }
}
