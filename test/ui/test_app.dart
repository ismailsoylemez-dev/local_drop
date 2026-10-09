import 'package:flutter/widgets.dart';
import 'package:local_drop/app.dart';
import 'package:local_drop/services/file_actions.dart';
import 'package:local_drop/state/server_controller.dart';
import 'package:provider/provider.dart';

/// Uygulamayı verilen controller ile kurar.
Widget testApp(ServerController controller) => MultiProvider(
  providers: [
    Provider<FileActions>.value(value: const FileActions()),
    ChangeNotifierProvider<ServerController>.value(value: controller),
  ],
  child: const LocalDropApp(),
);
