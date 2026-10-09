import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import '../core/constants.dart';
import '../core/lan_ip.dart';
import '../core/log.dart';

sealed class NetworkResult {
  const NetworkResult();
}

final class Connected extends NetworkResult {
  const Connected(this.ip);
  final String ip;

  @override
  bool operator ==(Object other) => other is Connected && other.ip == ip;

  @override
  int get hashCode => ip.hashCode;
}

final class NoNetwork extends NetworkResult {
  const NoNetwork();

  @override
  bool operator ==(Object other) => other is NoNetwork;

  @override
  int get hashCode => 0;
}

/// Wi-Fi/hotspot IPv4 tespiti. Konum izni istenmez: getWifiIP yalnız ipucu,
/// asıl kaynak arayüz listesidir (Android 12+'da getWifiIP aktif ağı, yani
/// mobil veriyi de döndürebilir).
class NetworkService {
  NetworkService({
    Future<String?> Function()? wifiIp,
    Future<List<IfaceAddress>> Function()? interfaces,
    this.pollInterval = AppConstants.networkPollInterval,
  }) : _wifiIp = wifiIp ?? NetworkInfo().getWifiIP,
       _interfaces = interfaces ?? _listInterfaces;

  final Future<String?> Function() _wifiIp;
  final Future<List<IfaceAddress>> Function() _interfaces;
  final Duration pollInterval;

  Future<NetworkResult> current() async {
    String? hint;
    try {
      hint = await _wifiIp();
    } catch (e) {
      Log.d('Net', 'getWifiIP hata: $e');
    }
    List<IfaceAddress> list;
    try {
      list = await _interfaces();
    } catch (e) {
      Log.d('Net', 'arayüz listesi hata: $e');
      list = const [];
    }
    final ip = pickLanIp(list, preferred: hint);
    return ip == null ? const NoNetwork() : Connected(ip);
  }

  /// İlk sonucu hemen, sonra yalnız değiştiğinde yayınlar.
  Stream<NetworkResult> watch() async* {
    NetworkResult? last;
    while (true) {
      final result = await current();
      if (result != last) {
        last = result;
        Log.d('Net', switch (result) {
          Connected(:final ip) => 'ip=$ip',
          NoNetwork() => 'no-network',
        });
        yield result;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  static Future<List<IfaceAddress>> _listInterfaces() async {
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final i in ifaces)
        for (final a in i.addresses) (iface: i.name, ip: a.address),
    ];
  }
}
