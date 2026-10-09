import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/app.dart';
import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/state/server_controller.dart';
import 'package:provider/provider.dart';

import '../fakes/fake_network_service.dart';

void main() {
  late FakeNetworkService network;

  Future<void> pumpApp(WidgetTester tester) async {
    network = FakeNetworkService();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ServerController(network: network),
        child: const LocalDropApp(),
      ),
    );
  }

  FilledButton startButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Başlat'));

  testWidgets('ana ekran: başlık, durum metni ve Başlat butonu', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Local Drop'), findsOneWidget);
    expect(find.text('Sunucu kapalı'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Başlat'), findsOneWidget);
  });

  testWidgets('NoNetwork: buton pasif + metin', (tester) async {
    await pumpApp(tester);
    network.controller.add(const NoNetwork());
    await tester.pump();

    expect(find.text('Ağ bağlantısı yok'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull);
  });

  testWidgets('Connected: IP metni + buton aktif', (tester) async {
    await pumpApp(tester);
    network.controller.add(const Connected('192.168.1.20'));
    await tester.pump();

    expect(find.text('IP: 192.168.1.20'), findsOneWidget);
    expect(startButton(tester).onPressed, isNotNull);
  });
}
