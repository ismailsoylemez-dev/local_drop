import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/lan_ip.dart';

List<IfaceAddress> wlan(List<String> ips) => [
  for (final ip in ips) (iface: 'wlan0', ip: ip),
];

void main() {
  test('192.168 > 10.x', () {
    expect(pickLanIp(wlan(['10.0.0.5', '192.168.1.20'])), '192.168.1.20');
  });

  test('loopback ve link-local elenir', () {
    expect(pickLanIp(wlan(['127.0.0.1', '169.254.3.4'])), isNull);
  });

  test('172.16-31 içi kabul, 172.32 elenir', () {
    expect(pickLanIp(wlan(['172.20.1.2', '172.32.0.1'])), '172.20.1.2');
  });

  test('hotspot arayüzü', () {
    expect(
      pickLanIp([(iface: 'wlan1', ip: '192.168.43.1')]),
      '192.168.43.1',
    );
  });

  test('mobil veri arayüzü elenir', () {
    expect(
      pickLanIp([
        (iface: 'rmnet_data0', ip: '10.12.0.7'),
        (iface: 'wlan0', ip: '192.168.1.5'),
      ]),
      '192.168.1.5',
    );
    expect(pickLanIp([(iface: 'v4-rmnet_data0', ip: '192.0.0.4')]), isNull);
    expect(pickLanIp([(iface: 'ccmni1', ip: '10.1.2.3')]), isNull);
  });

  test('boş liste', () {
    expect(pickLanIp([]), isNull);
  });

  test('preferred geçerli adaylardaysa seçilir', () {
    expect(
      pickLanIp(wlan(['192.168.1.20', '10.0.0.5']), preferred: '10.0.0.5'),
      '10.0.0.5',
    );
  });

  test('preferred mobil veriye aitse yok sayılır', () {
    expect(
      pickLanIp([
        (iface: 'rmnet_data0', ip: '10.12.0.7'),
        (iface: 'wlan1', ip: '192.168.43.1'),
      ], preferred: '10.12.0.7'),
      '192.168.43.1',
    );
  });

  test('bozuk adres elenir', () {
    expect(pickLanIp(wlan(['192.168.1', '192.168.1.300', 'abc'])), isNull);
  });
}
