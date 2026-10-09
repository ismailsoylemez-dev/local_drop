import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/stub_controller.dart';
import 'test_app.dart';

void main() {
  testWidgets('ilk açılış → onboarding; tamamla → bir daha görünmez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    await tester.pumpWidget(testApp(StubController(settings: settings)));

    expect(find.text('Aynı Wi-Fi ağı'), findsOneWidget);
    expect(find.text('Sunucu kapalı'), findsNothing);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    expect(find.text('QR\'ı okut veya PIN gir'), findsOneWidget);
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    expect(find.text('Güvenlik'), findsOneWidget);
    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Sunucu kapalı'), findsOneWidget);
    expect(settings.onboardingDone, isTrue);

    // Uygulama yeniden açılır: aynı kalıcı ayarlarla onboarding yok.
    final reloaded = await SettingsService.load();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(testApp(StubController(settings: reloaded)));
    expect(find.text('Aynı Wi-Fi ağı'), findsNothing);
    expect(find.text('Sunucu kapalı'), findsOneWidget);
  });

  testWidgets('Geç → doğrudan ana ekran', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    await tester.pumpWidget(testApp(StubController(settings: settings)));

    await tester.tap(find.text('Geç'));
    await tester.pumpAndSettle();
    expect(find.text('Sunucu kapalı'), findsOneWidget);
    expect(settings.onboardingDone, isTrue);
  });
}
