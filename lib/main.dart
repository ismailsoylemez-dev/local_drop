import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/file_actions.dart';
import 'services/network_service.dart';
import 'services/storage_service.dart';
import 'state/server_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.appDefault();
  runApp(
    MultiProvider(
      providers: [
        Provider<FileActions>.value(value: const FileActions()),
        ChangeNotifierProvider(
          create: (_) =>
              ServerController(network: NetworkService(), storage: storage),
        ),
      ],
      child: const LocalDropApp(),
    ),
  );
}
