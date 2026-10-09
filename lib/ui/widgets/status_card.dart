import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/network_service.dart';
import '../../state/server_controller.dart';

/// Sunucu durumu: kapalı → Başlat; açık → QR, URL, PIN, Durdur.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  static const double qrSize = 220;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ServerController>();
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final List<Widget> children = switch (c.status) {
      ServerStatus.running => [
        Text('Sunucu çalışıyor', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Bilgisayarda QR\'ı okutun veya adresi açın',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // QR koyu temada da okunabilsin diye beyaz zemin.
        QrImageView(
          data: c.url ?? '',
          size: qrSize,
          backgroundColor: Colors.white,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SelectableText(
                c.url ?? '',
                key: const Key('server-url'),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Adresi kopyala',
              icon: const Icon(Icons.copy),
              onPressed: () => _copyUrl(context, c.url),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('PIN', style: textTheme.labelMedium),
        Text(
          c.pin ?? '',
          key: const Key('server-pin'),
          style: textTheme.headlineMedium?.copyWith(letterSpacing: 4),
        ),
        const SizedBox(height: 12),
        if (c.notice case final notice?) ...[
          Text(
            notice,
            key: const Key('server-notice'),
            style: textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: c.stop,
          icon: const Icon(Icons.stop),
          label: const Text('Durdur'),
        ),
      ],
      ServerStatus.starting => [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text('Başlatılıyor…', style: textTheme.titleMedium),
      ],
      ServerStatus.error => [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
        const SizedBox(height: 8),
        Text(
          c.errorMessage ?? 'Bilinmeyen hata',
          style: textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _NetworkText(network: c.network),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: c.canStart ? c.start : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar dene'),
        ),
      ],
      ServerStatus.stopped => [
        Icon(Icons.wifi_tethering_off, size: 40, color: theme.hintColor),
        const SizedBox(height: 8),
        Text('Sunucu kapalı', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        _NetworkText(network: c.network),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: c.canStart ? c.start : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Başlat'),
        ),
      ],
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  Future<void> _copyUrl(BuildContext context, String? url) async {
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Adres kopyalandı')));
  }
}

class _NetworkText extends StatelessWidget {
  const _NetworkText({required this.network});

  final NetworkResult? network;

  @override
  Widget build(BuildContext context) {
    final text = switch (network) {
      null => 'Ağ kontrol ediliyor…',
      Connected(:final ip) => 'IP: $ip',
      NoNetwork() => 'Ağ bağlantısı yok',
    };
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}
