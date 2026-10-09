import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/log.dart';
import '../../services/storage_target.dart';
import '../../state/server_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _select(BuildContext context, SaveLocation? value) async {
    if (value == null) return;
    try {
      await context.read<ServerController>().setSaveLocation(value);
    } catch (e) {
      Log.d('Settings', 'kaydedilemedi: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ayar kaydedilemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ServerController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Alınan dosyaların kayıt yeri',
              style: textTheme.titleSmall,
            ),
          ),
          RadioGroup<SaveLocation>(
            groupValue: c.saveLocation,
            onChanged: (value) => _select(context, value),
            child: Column(
              children: [
                const RadioListTile<SaveLocation>(
                  value: SaveLocation.appFolder,
                  title: Text('Uygulama klasörü'),
                  subtitle: Text(
                    'Dosyalar uygulamada ve bilgisayardaki listede görünür.',
                  ),
                ),
                RadioListTile<SaveLocation>(
                  value: SaveLocation.downloads,
                  enabled: c.downloadsSupported,
                  title: const Text('İndirilenler'),
                  subtitle: Text(
                    c.downloadsSupported
                        ? 'Download/${AppConstants.downloadsSubfolder} '
                              'klasörüne taşınır; Dosyalar uygulamasında '
                              'görünür, uygulama listesinde görünmez.'
                        : 'Android 10 veya üstü gerekir.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
