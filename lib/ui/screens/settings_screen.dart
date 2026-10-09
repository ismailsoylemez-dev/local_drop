import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/log.dart';
import '../../services/settings_service.dart';
import '../../services/storage_target.dart';
import '../../state/server_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Ayarı kaydeder; hata → Türkçe SnackBar.
  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      Log.d('Settings', 'kaydedilemedi: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ayar kaydedilemedi')));
    }
  }

  Future<void> _editPort(BuildContext context, ServerController c) async {
    final port = await showDialog<int>(
      context: context,
      builder: (_) => _PortDialog(initial: c.port),
    );
    if (port == null || !context.mounted) return;
    await _save(context, () => c.setPort(port));
  }

  String _autoStopLabel(int minutes) => minutes == 0 ? 'Kapalı' : '$minutes dk';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ServerController>();
    final textTheme = Theme.of(context).textTheme;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          header('Alınan dosyaların kayıt yeri'),
          RadioGroup<SaveLocation>(
            groupValue: c.saveLocation,
            onChanged: (value) {
              if (value != null) _save(context, () => c.setSaveLocation(value));
            },
            child: Column(
              children: [
                const RadioListTile<SaveLocation>(
                  value: SaveLocation.appFolder,
                  title: Text('Uygulama klasörü'),
                  subtitle: Text(
                    'Dosyalar yalnız uygulamanın kendi klasöründe kalır; '
                    'Dosyalar uygulamasında görünmez.',
                  ),
                ),
                RadioListTile<SaveLocation>(
                  value: SaveLocation.downloads,
                  enabled: c.downloadsSupported,
                  title: const Text('İndirilenler'),
                  subtitle: Text(
                    c.downloadsSupported
                        ? 'Varsayılan. Download/'
                              '${AppConstants.downloadsSubfolder} klasörüne '
                              'kaydedilir; Dosyalar uygulamasında ve '
                              'uygulama listesinde görünür.'
                        : 'Android 10 veya üstü gerekir.',
                  ),
                ),
              ],
            ),
          ),
          header('Sunucu'),
          ListTile(
            key: const Key('setting-port'),
            title: const Text('Port'),
            subtitle: Text(
              '${c.port} (doluysa ${c.port + AppConstants.portRangeSize}\'e '
              'kadar denenir) · bir sonraki başlatmada geçerli',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editPort(context, c),
          ),
          ListTile(
            title: const Text('Otomatik durdurma'),
            subtitle: const Text('Bu süre transfer olmazsa sunucu kapanır'),
            trailing: DropdownButton<int>(
              key: const Key('setting-autostop'),
              value: c.autoStopMinutes,
              onChanged: (value) {
                if (value != null) {
                  _save(context, () => c.setAutoStopMinutes(value));
                }
              },
              items: [
                for (final m in AppConstants.autoStopOptions)
                  DropdownMenuItem(value: m, child: Text(_autoStopLabel(m))),
              ],
            ),
          ),
          header('Tema'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
                ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
              ],
              selected: {c.themeMode},
              onSelectionChanged: (s) =>
                  _save(context, () => c.setThemeMode(s.first)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortDialog extends StatefulWidget {
  const _PortDialog({required this.initial});

  final int initial;

  @override
  State<_PortDialog> createState() => _PortDialogState();
}

class _PortDialogState extends State<_PortDialog> {
  late final _text = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_text.text.trim());
    if (value == null || !SettingsService.isValidPort(value)) {
      setState(
        () => _error =
            '${AppConstants.minUserPort}–${AppConstants.maxUserPort} arası olmalı',
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Port'),
      content: TextField(
        key: const Key('port-field'),
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Kaydet')),
      ],
    );
  }
}
