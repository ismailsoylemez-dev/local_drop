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
