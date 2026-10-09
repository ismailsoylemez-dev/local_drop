import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  final docs = await getApplicationDocumentsDirectory();
  final storage = await StorageService.appDefault();
  final settings = SettingsService(
    File(
      '${docs.path}${Platform.pathSeparator}${AppConstants.settingsFileName}',
    ),
  );
  await settings.load();

  const device = NativeDeviceChannel();
  final transfers = WakelockPolicy(device);
  final target = StorageTarget(
    adapter: device,
    location: () => settings.saveLocation,
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
            createServer: (s, restart) => ServerService(
              storage: s,
              transfers: MultiTransferObserver([transfers, restart]),
              target: target,
            ),
          ),
        ),
      ],
      child: const LocalDropApp(),
    ),
  );
}
