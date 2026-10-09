import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/network_service.dart';

import '../fakes/stub_controller.dart';
import 'finders.dart';
import 'test_app.dart';

void main() {
  late StubController c;

  Future<void> pumpApp(WidgetTester tester) async {
    c = StubController();
    await tester.pumpWidget(testApp(c));
  }

  testWidgets('ana ekran: başlık, durum metni ve Başlat butonu', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Local Drop'), findsOneWidget);
    expect(find.text('Sunucu kapalı'), findsOneWidget);
    expect(buttonWithText<FilledButton>('Başlat'), findsOneWidget);
  });

  testWidgets('NoNetwork: buton pasif + metin', (tester) async {
    await pumpApp(tester);
    c
      ..stubNetwork = const NoNetwork()
      ..update();
    await tester.pump();

    expect(find.text('Ağ bağlantısı yok'), findsOneWidget);
    expect(buttonWidget<FilledButton>(tester, 'Başlat').onPressed, isNull);
  });

  testWidgets('Connected: IP metni + buton aktif', (tester) async {
    await pumpApp(tester);

    expect(find.text('IP: 192.168.1.20'), findsOneWidget);
    expect(buttonWidget<FilledButton>(tester, 'Başlat').onPressed, isNotNull);
    await tester.tap(buttonWithText<FilledButton>('Başlat'));
    expect(c.startCalls, 1);
  });
}
