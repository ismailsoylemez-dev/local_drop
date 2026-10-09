import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/log.dart';
import '../core/wakelock_policy.dart';
import 'storage_target.dart';

/// Kotlin `DeviceChannel` istemcisi: kilitler + MediaStore.
class NativeDeviceChannel implements LockAdapter, MediaStoreAdapter {
  const NativeDeviceChannel();

  static const _channel = MethodChannel(AppConstants.deviceChannel);

  @override
  void acquire() => _call('acquireLocks');

  @override
  void release() => _call('releaseLocks');

  void _call(String method) {
    Log.d('Lock', method);
    unawaited(
      _channel
          .invokeMethod<void>(method)
          .catchError((Object e) => Log.d('Lock', '$method hata: $e')),
    );
  }

  @override
  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('downloadsSupported') ?? false;

  /// `Download/LocalDrop` yolu (Android 11+), aksi halde null.
  Future<String?> downloadsDir() => _channel.invokeMethod<String>(
    'downloadsDir',
    {'folder': AppConstants.downloadsSubfolder},
  );

  @override
  Future<void> saveToDownloads(File source, String name) =>
      _channel.invokeMethod<void>('saveToDownloads', {
        'path': source.path,
        'name': name,
        'folder': AppConstants.downloadsSubfolder,
      });
}
