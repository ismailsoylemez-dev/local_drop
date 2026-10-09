import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/lan_ip.dart';
import 'package:local_drop/services/network_service.dart';

void main() {
  test('watch: yalnız değişince yayınlar', () async {
    final sequence = <List<IfaceAddress>>[
      [(iface: 'wlan0', ip: '192.168.1.5')],
      [(iface: 'wlan0', ip: '192.168.1.5')],
      [],
      [(iface: 'wlan1', ip: '192.168.43.1')],
    ];
    var i = 0;
    final service = NetworkService(
      wifiIp: () async => null,
      interfaces: () async => sequence[i < sequence.length - 1 ? i++ : i],
      pollInterval: Duration.zero,
    );

    final results = await service.watch().take(3).toList();
    expect(results, const [
      Connected('192.168.1.5'),
      NoNetwork(),
      Connected('192.168.43.1'),
    ]);
  });

  test('current: getWifiIP hata verirse arayüz listesine düşer', () async {
    final service = NetworkService(
      wifiIp: () async => throw Exception('plugin yok'),
      interfaces: () async => [(iface: 'wlan0', ip: '10.0.0.9')],
    );
    expect(await service.current(), const Connected('10.0.0.9'));
  });

  test('varsayılan arayüz listesi gerçek sistemden okunur', () async {
    final service = NetworkService(wifiIp: () async => null);
    final result = await service.current();
    expect(result, anyOf(isA<Connected>(), isA<NoNetwork>()));
  });

  test('arayüz listesi hata verirse NoNetwork', () async {
    final service = NetworkService(
      wifiIp: () async => '192.168.1.5',
      interfaces: () async => throw const SocketException('yok'),
    );
    expect(await service.current(), const NoNetwork());
  });
}
