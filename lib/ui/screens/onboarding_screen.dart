import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/log.dart';
import '../../state/server_controller.dart';

typedef _Page = ({IconData icon, String title, String body});

const List<_Page> _pages = [
  (
    icon: Icons.wifi,
    title: 'Aynı Wi-Fi ağı',
    body:
        'Telefon ile bilgisayar aynı Wi-Fi ağında (veya telefonun '
        'hotspot\'unda) olmalı. İnternet gerekmez; dosyalar ağdan dışarı çıkmaz.',
  ),
  (
    icon: Icons.qr_code_2,
    title: 'QR\'ı okut veya PIN gir',
    body:
        'Başlat\'a bas. Bilgisayarın tarayıcısında QR\'daki adresi aç. QR '
        'okutamazsan adresin sonuna /login yazıp ekrandaki PIN\'i gir.',
  ),
  (
    icon: Icons.lock_outline,
    title: 'Güvenlik',
    body:
        'Adres ve PIN yalnız sende; her başlatmada yenilenir. İşin bitince '
        'sunucuyu kapat. Uzun süre transfer olmazsa kendiliğinden kapanır.',
  ),
];

/// İlk açılış tanıtımı (3 sayfa). Tamamlanınca bir daha gösterilmez.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      await context.read<ServerController>().completeOnboarding();
    } catch (e) {
      Log.d('Settings', 'onboarding kaydedilemedi: $e');
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Geç')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          page.icon,
                          size: 96,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page.title,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    margin: const EdgeInsets.all(4),
                    width: i == _index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Başla' : 'İleri'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
