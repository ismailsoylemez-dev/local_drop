import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/format.dart';

void main() {
  test('formatSize', () {
    expect(formatSize(0), '0 B');
    expect(formatSize(1023), '1023 B');
    expect(formatSize(1024), '1,0 KB');
    expect(formatSize(1536), '1,5 KB');
    expect(formatSize(5 * 1024 * 1024), '5,0 MB');
    expect(formatSize(1073741824), '1,0 GB');
    expect(formatSize(3 * 1024 * 1024 * 1024 * 1024), '3,0 TB');
  });
}
