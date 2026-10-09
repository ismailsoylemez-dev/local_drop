const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

/// Bayt → `0 B`, `1,5 KB`, `1,0 GB` (Türkçe ondalık virgül, 1024 tabanı).
/// Web arayüzündeki `formatSize` JS fonksiyonu aynı kuralı uygular.
String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(1).replaceAll('.', ',')} ${_units[unit]}';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Yerel saatle `gg.aa.yyyy ss:dd`.
String formatDate(DateTime time) {
  final t = time.toLocal();
  return '${_two(t.day)}.${_two(t.month)}.${t.year} '
      '${_two(t.hour)}:${_two(t.minute)}';
}
