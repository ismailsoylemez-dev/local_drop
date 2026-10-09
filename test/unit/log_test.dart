import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/log.dart';

void main() {
  test('mask: ilk 2 karakter + **', () {
    expect(Log.mask('abcdef'), 'ab**');
  });

  test('mask: boş değer', () {
    expect(Log.mask(''), '**');
  });
}
