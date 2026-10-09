import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import 'storage_target.dart';

/// Kalıcı ayarlar (SharedPreferences). Geçersiz/bilinmeyen değer → varsayılan.
class SettingsService {
  SettingsService(this._prefs);

  static Future<SettingsService> load() async =>
      SettingsService(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kSaveLocation = 'saveLocation';
  static const _kPort = 'port';
  static const _kAutoStop = 'autoStopMinutes';
  static const _kTheme = 'themeMode';
  static const _kOnboarding = 'onboardingDone';

  SaveLocation get saveLocation =>
      _enumOr(SaveLocation.values, _kSaveLocation, SaveLocation.downloads);

  Future<void> setSaveLocation(SaveLocation value) =>
      _prefs.setString(_kSaveLocation, value.name);

  /// Sunucunun denediği ilk port (aralık: port … port+10).
  int get port {
    final value = _prefs.getInt(_kPort);
    return value != null && isValidPort(value)
        ? value
        : AppConstants.portRangeStart;
  }

  static bool isValidPort(int value) =>
      value >= AppConstants.minUserPort && value <= AppConstants.maxUserPort;

  Future<void> setPort(int value) {
    if (!isValidPort(value)) throw RangeError.value(value, 'port');
    return _prefs.setInt(_kPort, value);
  }

  /// Transfer olmadan bu kadar dakika geçince sunucu kapanır; 0 = kapalı.
  int get autoStopMinutes {
    final value = _prefs.getInt(_kAutoStop);
    return value != null && AppConstants.autoStopOptions.contains(value)
        ? value
        : AppConstants.defaultAutoStopMinutes;
  }

  Future<void> setAutoStopMinutes(int value) {
    if (!AppConstants.autoStopOptions.contains(value)) {
      throw RangeError.value(value, 'autoStopMinutes');
    }
    return _prefs.setInt(_kAutoStop, value);
  }

  ThemeMode get themeMode =>
      _enumOr(ThemeMode.values, _kTheme, ThemeMode.system);

  Future<void> setThemeMode(ThemeMode value) =>
      _prefs.setString(_kTheme, value.name);

  bool get onboardingDone => _prefs.getBool(_kOnboarding) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_kOnboarding, true);

  T _enumOr<T extends Enum>(List<T> values, String key, T fallback) {
    final name = _prefs.getString(key);
    return values.firstWhere((v) => v.name == name, orElse: () => fallback);
  }
}
