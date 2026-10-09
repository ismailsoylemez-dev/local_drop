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

    // TODO(F5): QR + durum kartı.
    final List<Widget> statusWidgets = switch (controller.status) {
      ServerStatus.running => [
        Text('Sunucu çalışıyor', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        SelectableText(controller.url ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('PIN: ${controller.pin ?? ''}', style: textTheme.titleLarge),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: controller.stop, child: const Text('Durdur')),
      ],
      ServerStatus.starting => [
        Text('Başlatılıyor…', style: textTheme.titleMedium),
        const SizedBox(height: 16),
        const CircularProgressIndicator(),
      ],
      ServerStatus.stopped || ServerStatus.error => [
        Text('Sunucu kapalı', style: textTheme.titleMedium),
        if (controller.errorMessage case final message?) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(networkText, style: textTheme.bodyMedium),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.canStart ? controller.start : null,
          child: const Text('Başlat'),
        ),
      ],
    };

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: statusWidgets,
          ),
        ),
      ),
    );
  }
}
