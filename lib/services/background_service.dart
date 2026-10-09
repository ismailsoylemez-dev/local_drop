import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/constants.dart';
import '../core/log.dart';

/// Ön plan servisinden gelen olay.
enum BackgroundEvent {
  /// Bildirimdeki "Durdur".
  stopPressed,

  /// Android 15+ dataSync süre limiti doldu; servis kapanıyor.
  timeout,
}

/// Sunucu açıkken süreci ayakta tutan kalıcı bildirim.
abstract interface class BackgroundService {
  Stream<BackgroundEvent> get events;

  /// Bildirim izni (13+). İzin yoksa sunucu yine çalışır, kullanıcı uyarılır.
  Future<bool> ensureNotificationPermission();

  /// Başarısızsa hata mesajı, başarılıysa null.
  Future<String?> start(String address);

  /// Bildirim metnini günceller (ör. IP değişti).
  Future<void> update(String address);

  Future<void> stop();
}

/// flutter_foreground_task ile ön plan servisi (dataSync, K5).
class ForegroundBackgroundService implements BackgroundService {
  ForegroundBackgroundService() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.fgsChannelId,
        channelName: AppConstants.fgsChannelName,
        channelDescription: 'Sunucu açıkken gösterilir',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // Kilitler transfer sayacına göre native tutulur (WakelockPolicy).
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final _events = StreamController<BackgroundEvent>.broadcast();

  @override
  Stream<BackgroundEvent> get events => _events.stream;

  void _onData(Object data) {
    final event = switch (data) {
      AppConstants.fgsMsgStop => BackgroundEvent.stopPressed,
      AppConstants.fgsMsgTimeout => BackgroundEvent.timeout,
      _ => null,
    };
    if (event != null) _events.add(event);
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    var permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      permission = await FlutterForegroundTask.requestNotificationPermission();
    }
    Log.d('Fgs', 'notification permission=$permission');
    return permission == NotificationPermission.granted;
  }

  @override
  Future<String?> start(String address) async {
    final result = await FlutterForegroundTask.startService(
      serviceId: AppConstants.fgsServiceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Local Drop çalışıyor',
      notificationText: address,
      notificationButtons: const [
        NotificationButton(id: AppConstants.fgsStopButtonId, text: 'Durdur'),
      ],
      callback: localDropTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      Log.d('Fgs', 'start hata: ${result.error}');
      return 'Arka plan servisi başlatılamadı';
    }
    Log.d('Fgs', 'started $address');
    return null;
  }

  @override
  Future<void> update(String address) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(notificationText: address);
    Log.d('Fgs', 'updated $address');
  }

  @override
  Future<void> stop() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
    Log.d('Fgs', 'stopped');
  }
}

/// Servis isolate'inin giriş noktası.
@pragma('vm:entry-point')
void localDropTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_LocalDropTaskHandler());
}

/// Servis isolate'i yalnız bildirimi taşır; sunucu ana isolate'te çalışır
/// (motor MainActivity'de önbellekte, uygulama kaydırılınca da yaşar).
class _LocalDropTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (isTimeout) {
      FlutterForegroundTask.sendDataToMain(AppConstants.fgsMsgTimeout);
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == AppConstants.fgsStopButtonId) {
      FlutterForegroundTask.sendDataToMain(AppConstants.fgsMsgStop);
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}
