import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/safe_name.dart';

void main() {
  test('boşsa aynen döner', () {
    expect(uniqueName('a.txt', (_) => false), 'a.txt');
  });

  test('a.txt varken → a (1).txt', () {
    expect(uniqueName('a.txt', {'a.txt'}.contains), 'a (1).txt');
  });

  test('a (1).txt da varsa → a (2).txt', () {
    expect(uniqueName('a.txt', {'a.txt', 'a (1).txt'}.contains), 'a (2).txt');
  });

  test('uzantısız ad', () {
    expect(uniqueName('README', {'README'}.contains), 'README (1)');
  });

  test('çok noktalı ad son uzantıyı korur', () {
    expect(uniqueName('a.tar.gz', {'a.tar.gz'}.contains), 'a.tar (1).gz');
  });
}
