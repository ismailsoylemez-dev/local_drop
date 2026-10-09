import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/storage_target.dart';
import 'package:local_drop/state/server_controller.dart';

import '../fakes/stub_controller.dart';
import 'test_app.dart';

void main() {
  Future<void> openSettings(WidgetTester tester, StubController c) async {
    await tester.pumpWidget(testApp(c));
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
  }

  RadioListTile<SaveLocation> tile(WidgetTester tester, String title) =>
      tester.widget(find.widgetWithText(RadioListTile<SaveLocation>, title));

  testWidgets('İndirilenler seçilir → ayar kaydedilir', (tester) async {
    final c = StubController();
    await openSettings(tester, c);
    expect(find.text('Alınan dosyaların kayıt yeri'), findsOneWidget);

    await tester.tap(find.text('İndirilenler'));
    await tester.pumpAndSettle();
    expect(c.saveLocation, SaveLocation.downloads);
    expect(find.textContaining('Download/LocalDrop'), findsOneWidget);
  });

  testWidgets('Android 10 altı → İndirilenler pasif', (tester) async {
    final c = StubController()..stubDownloadsSupported = false;
    await openSettings(tester, c);
    expect(tile(tester, 'İndirilenler').enabled, isFalse);
    expect(find.text('Android 10 veya üstü gerekir.'), findsOneWidget);

    await tester.tap(find.text('İndirilenler'));
    await tester.pumpAndSettle();
    expect(c.saveLocation, SaveLocation.appFolder);
  });

  testWidgets('çalışırken uyarı (bildirim izni yok) görünür', (tester) async {
    final c = StubController()
      ..stubStatus = ServerStatus.running
      ..stubUrl = 'http://192.168.1.20:8080/?t=x'
      ..stubPin = '123456'
      ..stubNotice = 'Bildirim izni yok: sunucu çalışıyor';
    await tester.pumpWidget(testApp(c));
    expect(find.byKey(const Key('server-notice')), findsOneWidget);
    expect(find.text('Bildirim izni yok: sunucu çalışıyor'), findsOneWidget);
  });
}
