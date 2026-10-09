import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../server/server_event.dart';
import '../../state/server_controller.dart';
import '../widgets/files_panel.dart';
import '../widgets/status_card.dart';
import '../widgets/text_banner.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Bu genişlik ve üstünde QR ile liste yan yana.
  static const double wideBreakpoint = 600;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<ServerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = context.read<ServerController>().events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(ServerEvent event) {
    if (!mounted) return;
    final message = switch (event) {
      FileUploaded(:final name) => '$name alındı',
      ServerErrorEvent(:final message) => message,
      FileDeleted() || TextReceived() => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final lastText = context.select<ServerController, String?>(
      (c) => c.lastText,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appTitle),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final banner = lastText == null ? null : TextBanner(text: lastText);
            if (constraints.maxWidth >= HomeScreen.wideBreakpoint) {
              return Row(
                key: const Key('layout-wide'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Column(children: [?banner, const StatusCard()]),
                    ),
                  ),
                  const Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(8),
                      child: FilesPanel(),
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              key: const Key('layout-narrow'),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [?banner, const StatusCard(), const FilesPanel()],
              ),
            );
          },
        ),
      ),
    );
  }
}
