import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/settings_service.dart';
import 'package:local_drop/services/storage_target.dart';
import 'package:local_drop/state/server_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('F8 ayarları', () {
    late SettingsService settings;
    late StubController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'onboardingDone': true});
      settings = await SettingsService.load();
      c = StubController(settings: settings);
    });

    testWidgets('port: geçersiz → hata; geçerli → kaydedilir', (tester) async {
      await openSettings(tester, c);
      expect(find.textContaining('8080 (doluysa 8090'), findsOneWidget);

      await tester.tap(find.byKey(const Key('setting-port')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('port-field')), '80');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('1024–65525 arası olmalı'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('port-field')), '9000');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(settings.port, 9000);
      expect(find.textContaining('9000 (doluysa 9010'), findsOneWidget);
    });

    testWidgets('otomatik durdurma seçilir', (tester) async {
      await openSettings(tester, c);
      expect(find.text('15 dk'), findsOneWidget);
      await tester.tap(find.byKey(const Key('setting-autostop')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kapalı').last);
      await tester.pumpAndSettle();
      expect(settings.autoStopMinutes, 0);
    });

    testWidgets('tema: Koyu seçilince uygulama koyu temaya geçer', (
      tester,
    ) async {
      await openSettings(tester, c);
      await tester.tap(find.text('Koyu'));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.dark);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}
