import 'constants.dart';

/// Bir ağ arayüzündeki IPv4 adresi.
typedef IfaceAddress = ({String iface, String ip});

/// Yerel ağda (Wi-Fi/hotspot) PC'nin erişebileceği IPv4 adresini seçer.
///
/// Öncelik: 192.168.x > 10.x > 172.16–31.x. Loopback, link-local, özel aralık
/// dışı adresler ve mobil veri arayüzleri elenir. [preferred] (ör. getWifiIP
/// sonucu) geçerli adaylar arasındaysa o seçilir.
String? pickLanIp(List<IfaceAddress> addresses, {String? preferred}) {
  final candidates = <String>[];
  for (final a in addresses) {
    if (_isMobileIface(a.iface)) continue;
    if (_privateRank(a.ip) == null) continue;
    candidates.add(a.ip);
  }
  if (candidates.isEmpty) return null;
  if (preferred != null && candidates.contains(preferred)) return preferred;

  candidates.sort((a, b) => _privateRank(a)!.compareTo(_privateRank(b)!));
  return candidates.first;
}

bool _isMobileIface(String iface) {
  final name = iface.toLowerCase();
  return AppConstants.mobileIfaceMarkers.any(name.contains);
}

/// Özel IPv4 aralığının önceliği (küçük = daha iyi); aralık dışıysa null.
int? _privateRank(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return null;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((o) => o == null || o < 0 || o > 255)) return null;
  final a = octets[0]!;
  final b = octets[1]!;
  if (a == 192 && b == 168) return 0;
  if (a == 10) return 1;
  if (a == 172 && b >= 16 && b <= 31) return 2;
  return null;
}
