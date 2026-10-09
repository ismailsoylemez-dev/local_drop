import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/server_controller.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ServerController(),
      child: const LocalDropApp(),
    ),
  );
}
