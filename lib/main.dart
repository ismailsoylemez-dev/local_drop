import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/constants.dart';
import 'core/wakelock_policy.dart';
import 'services/background_service.dart';
import 'services/device_channel.dart';
import 'services/file_actions.dart';
import 'services/network_service.dart';
import 'services/server_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'services/storage_target.dart';
import 'state/server_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.appDefault();
  final settings = await SettingsService.load();

  const device = NativeDeviceChannel();
  var downloadsOk = false;
  try {
    downloadsOk = await device.isSupported();
    final dir = await device.downloadsDir();
    if (dir != null) storage.exportDir = Directory(dir);
  } catch (_) {
    // Kanal yoksa (ör. eski Android) dosyalar uygulama klasöründe kalır.
  }
  final transfers = WakelockPolicy(device);
  final target = StorageTarget(
    adapter: device,
    location: () =>
        downloadsOk ? settings.saveLocation : SaveLocation.appFolder,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<FileActions>.value(value: const FileActions()),
        ChangeNotifierProvider(
          create: (_) => ServerController(
            network: NetworkService(),
            storage: storage,
            settings: settings,
            mediaStore: device,
            background: ForegroundBackgroundService(),
            // Port ayarı her başlatmada okunur (sunucu yeniden oluşturulur).
            createServer: (s, observer) => ServerService(
              storage: s,
              portStart: settings.port,
              portEnd: settings.port + AppConstants.portRangeSize,
              transfers: MultiTransferObserver([transfers, observer]),
              target: target,
            ),
          ),
        ),
      ],
      child: const LocalDropApp(),
    ),
  );
}
