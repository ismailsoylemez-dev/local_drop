import 'constants.dart';

final _forbidden = RegExp(r'[/\\:*?"<>|\x00-\x1f\x7f]');
final _dotRun = RegExp(r'\.{2,}');
final _leading = RegExp(r'^[\s.]+');
final _trailing = RegExp(r'[\s.]+$');

/// Dosya adını tek bir güvenli yol bileşenine indirger: ayraç, `..`, kontrol
/// karakteri içermez; baştaki nokta/boşluk atılır; en fazla
/// [AppConstants.maxNameLength] karakter (uzantı korunur); boşsa `dosya`.
String safeName(String input) {
  var name = input
      .replaceAll(_forbidden, '_')
      .replaceAll(_dotRun, '.')
      .replaceFirst(_leading, '')
      .replaceFirst(_trailing, '');
  if (name.isEmpty) return AppConstants.fallbackFileName;

  final runes = name.runes.toList();
  if (runes.length <= AppConstants.maxNameLength) return name;

  final (base, ext) = splitExtension(name);
  final extRunes = ext.runes.length;
  if (extRunes >= AppConstants.maxNameLength) {
    return String.fromCharCodes(runes.take(AppConstants.maxNameLength));
  }
  final keep = AppConstants.maxNameLength - extRunes;
  return String.fromCharCodes(base.runes.take(keep)) + ext;
}

/// `ad.uzanti` → (`ad`, `.uzanti`). Baştaki nokta uzantı sayılmaz.
(String, String) splitExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return (name, '');
  return (name.substring(0, dot), name.substring(dot));
}

/// [name] kullanılıyorsa `ad (1).ext`, `ad (2).ext`… ilk boş olanı döner.
String uniqueName(String name, bool Function(String) taken) {
  if (!taken(name)) return name;
  final (base, ext) = splitExtension(name);
  for (var i = 1; ; i++) {
    final candidate = '$base ($i)$ext';
    if (!taken(candidate)) return candidate;
  }
}
