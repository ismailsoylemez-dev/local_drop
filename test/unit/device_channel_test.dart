import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/constants.dart';
import 'package:local_drop/services/device_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AppConstants.deviceChannel);
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'downloadsSupported' => true,
        'acquireLocks' || 'releaseLocks' => null,
        'saveToDownloads' => 'content://media/1',
        _ => throw PlatformException(code: 'X'),
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const device = NativeDeviceChannel();

  test('kilitler native kanala gider', () async {
    device
      ..acquire()
      ..release();
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((c) => c.method), ['acquireLocks', 'releaseLocks']);
  });

  test('kanal hatası kilit çağrısını düşürmez', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'FAIL'),
    );
    expect(device.acquire, returnsNormally);
    await Future<void>.delayed(Duration.zero);
  });

  test('isSupported ve saveToDownloads argümanları', () async {
    expect(await device.isSupported(), isTrue);
    await device.saveToDownloads(File('/x/a.pdf'), 'a.pdf');
    final save = calls.last;
    expect(save.method, 'saveToDownloads');
    expect(save.arguments, {
      'path': File('/x/a.pdf').path,
      'name': 'a.pdf',
      'folder': 'LocalDrop',
    });
  });

  test('isSupported: null yanıt → false', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await device.isSupported(), isFalse);
  });
}
