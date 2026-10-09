import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/settings_service.dart';
import 'package:local_drop/services/storage_target.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SettingsService> load([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SettingsService.load();
  }

  test('varsayılanlar', () async {
    final s = await load();
    expect(s.saveLocation, SaveLocation.downloads);
    expect(s.port, 8080);
    expect(s.autoStopMinutes, 15);
    expect(s.themeMode, ThemeMode.system);
    expect(s.onboardingDone, isFalse);
  });

  test('kaydet → yeni örnek aynı değerleri okur', () async {
    final s = await load();
    await s.setSaveLocation(SaveLocation.appFolder);
    await s.setPort(9000);
    await s.setAutoStopMinutes(30);
    await s.setThemeMode(ThemeMode.dark);
    await s.setOnboardingDone();

    final again = await SettingsService.load();
    expect(again.saveLocation, SaveLocation.appFolder);
    expect(again.port, 9000);
    expect(again.autoStopMinutes, 30);
    expect(again.themeMode, ThemeMode.dark);
    expect(again.onboardingDone, isTrue);
  });

  test('bozuk / bilinmeyen değerler → varsayılan', () async {
    final s = await load({
      'saveLocation': 'bulut',
      'port': 80,
      'autoStopMinutes': 7,
      'themeMode': 'mor',
    });
    expect(s.saveLocation, SaveLocation.downloads);
    expect(s.port, 8080);
    expect(s.autoStopMinutes, 15);
    expect(s.themeMode, ThemeMode.system);
  });

  test('geçersiz port / süre kaydedilmez', () async {
    final s = await load();
    expect(() => s.setPort(80), throwsRangeError);
    expect(() => s.setPort(70000), throwsRangeError);
    expect(() => s.setAutoStopMinutes(7), throwsRangeError);
    expect(SettingsService.isValidPort(1024), isTrue);
    expect(SettingsService.isValidPort(65525), isTrue);
    expect(SettingsService.isValidPort(65526), isFalse);
  });
}
