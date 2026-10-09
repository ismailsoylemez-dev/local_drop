import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/safe_name.dart';

void main() {
  void expectSafe(String name) {
    expect(name, isNot(contains('..')));
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains(r'\')));
  }

  test('yol geçişi temizlenir', () {
    final name = safeName('../../etc/passwd');
    expectSafe(name);
    expect(name, endsWith('etc_passwd'));
  });

  test('ayraçlar _ olur', () {
    expect(safeName(r'a/b\c.txt'), 'a_b_c.txt');
  });

  test('yasak karakterler ve kontrol karakterleri', () {
    expect(safeName('a:b*c?"d<e>f|g\x00h\x1fi.txt'), 'a_b_c__d_e_f_g_h_i.txt');
  });

  test('baştaki boşluk ve nokta atılır', () {
    expect(safeName('  .gizli'), 'gizli');
  });

  test('con.txt korunur', () {
    expect(safeName('con.txt'), 'con.txt');
  });

  test('Türkçe ve emoji korunur', () {
    expect(safeName('şöğüİı.pdf'), 'şöğüİı.pdf');
    expect(safeName('rapor 📄.pdf'), 'rapor 📄.pdf');
  });

  test('uzun ad 200 karaktere kısalır, uzantı korunur', () {
    final name = safeName('${'a' * 300}.pdf');
    expect(name.runes.length, lessThanOrEqualTo(200));
    expect(name, endsWith('.pdf'));
  });

  test('uzun emoji adı vekil çiftleri bölmez', () {
    final name = safeName('${'😀' * 250}.txt');
    expect(name.runes.length, 200);
    expect(name, endsWith('.txt'));
    expect(() => Uri.encodeComponent(name), returnsNormally);
  });

  test('boş ad → dosya', () {
    expect(safeName(''), 'dosya');
    expect(safeName(' . .. '), 'dosya');
  });
}
