import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/state/server_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../fakes/stub_controller.dart';
import 'finders.dart';
import 'test_app.dart';

void main() {
  const url = 'http://192.168.1.20:8080/?t=Tok3nTok3nTok3n1';

  Future<StubController> pumpWith(
    WidgetTester tester,
    void Function(StubController c) setup,
  ) async {
    final c = StubController();
    setup(c);
    await tester.pumpWidget(testApp(c));
    return c;
  }

  testWidgets('running → QR + URL + PIN + Durdur', (tester) async {
    await pumpWith(tester, (c) {
      c
        ..stubStatus = ServerStatus.running
        ..stubUrl = url
        ..stubPin = '123456';
    });

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr, isNotNull);
    final urlText = tester.widget<SelectableText>(
      find.byKey(const Key('server-url')),
    );
    expect(urlText.data, url);
    expect(find.text('123456'), findsOneWidget);
    expect(buttonWithText<OutlinedButton>('Durdur'), findsOneWidget);
    expect(find.byTooltip('Adresi kopyala'), findsOneWidget);
  });

  testWidgets('stopped → QR yok, Başlat var', (tester) async {
    await pumpWith(tester, (_) {});
    expect(find.byType(QrImageView), findsNothing);
    expect(buttonWithText<FilledButton>('Başlat'), findsOneWidget);
  });

  testWidgets('starting → progress', (tester) async {
    await pumpWith(tester, (c) => c.stubStatus = ServerStatus.starting);
    expect(find.text('Başlatılıyor…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('error → mesaj + Tekrar dene start çağırır', (tester) async {
    final c = await pumpWith(tester, (c) {
      c
        ..stubStatus = ServerStatus.error
        ..stubError = 'Port bulunamadı';
    });
    expect(find.text('Port bulunamadı'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(buttonWithText<FilledButton>('Tekrar dene'));
    expect(c.startCalls, 1);
  });

  testWidgets('gelen metin → banner; Kapat clearText', (tester) async {
    final c = await pumpWith(tester, (c) => c.stubText = 'merhaba');
    expect(find.text('Bilgisayardan metin geldi'), findsOneWidget);
    expect(find.text('merhaba'), findsOneWidget);
    expect(buttonWithText<FilledButton>('Kopyala'), findsOneWidget);

    await tester.tap(buttonWithText<TextButton>('Kapat'));
    await tester.pump();
    expect(c.clearTextCalls, 1);
    expect(find.text('Bilgisayardan metin geldi'), findsNothing);
  });

  group('yerleşim', () {
    Future<void> setWidth(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('genişlik 800 → Row (yan yana)', (tester) async {
      await setWidth(tester, 800);
      await pumpWith(tester, (_) {});
      expect(find.byKey(const Key('layout-wide')), findsOneWidget);
      expect(find.byKey(const Key('layout-narrow')), findsNothing);
    });

    testWidgets('genişlik 360 → Column (alt alta)', (tester) async {
      await setWidth(tester, 360);
      await pumpWith(tester, (c) {
        c
          ..stubStatus = ServerStatus.running
          ..stubUrl = url
          ..stubPin = '123456';
      });
      expect(find.byKey(const Key('layout-narrow')), findsOneWidget);
      expect(find.byKey(const Key('layout-wide')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
