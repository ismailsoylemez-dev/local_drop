import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/state/server_controller.dart';

import '../fakes/fake_network_service.dart';
import '../fakes/fake_server_service.dart';
import '../fakes/stub_controller.dart';
import 'test_app.dart';

void main() {
  final modified = DateTime(2026, 10, 9, 14, 5);

  testWidgets('3 dosya → 3 satır, boyut ve tarih biçimli', (tester) async {
    final c = StubController()
      ..stubFiles = [
        (name: 'a.txt', size: 12, modified: modified),
        (name: 'b.pdf', size: 1536, modified: modified),
        (name: 'c.zip', size: 1073741824, modified: modified),
      ];
    await tester.pumpWidget(testApp(c));

    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('12 B · 09.10.2026 14:05'), findsOneWidget);
    expect(find.text('1,5 KB · 09.10.2026 14:05'), findsOneWidget);
    expect(find.text('1,0 GB · 09.10.2026 14:05'), findsOneWidget);
  });

  testWidgets('boş liste → bilgi metni', (tester) async {
    await tester.pumpWidget(testApp(StubController()));
    expect(find.textContaining('Henüz dosya yok'), findsOneWidget);
    expect(find.text('Bilgisayara gönder'), findsOneWidget);
  });

  testWidgets('uzun bas → Sil → onay → controller.deleteFile', (tester) async {
    final c = StubController()
      ..stubFiles = [(name: 'sil.txt', size: 1, modified: modified)];
    await tester.pumpWidget(testApp(c));

    await tester.longPress(find.text('sil.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Paylaş'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Dosya silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(c.deleted, ['sil.txt']);
    expect(find.text('sil.txt silindi'), findsOneWidget);
  });

  testWidgets('silme onayında Vazgeç → silinmez', (tester) async {
    final c = StubController()
      ..stubFiles = [(name: 'kalsin.txt', size: 1, modified: modified)];
    await tester.pumpWidget(testApp(c));

    await tester.longPress(find.text('kalsin.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(c.deleted, isEmpty);
  });

  testWidgets('uploaded olayı → SnackBar + satır eklenir', (tester) async {
    late Directory tmp;
    late ServerController c;
    late FakeServerService server;
    final network = FakeNetworkService();

    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('ld_ui_');
      final storage = StorageService(Directory('${tmp.path}/r'));
      await storage.ensureExists();
      c = ServerController(
        network: network,
        storage: storage,
        createServer: (s) => server = FakeServerService(s),
      );
      network.controller.add(const Connected('192.168.1.20'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await c.start();
    });
    addTearDown(() async {
      c.dispose();
      await tmp.delete(recursive: true);
    });

    await tester.pumpWidget(testApp(c));
    expect(find.byType(ListTile), findsNothing);

    await tester.runAsync(() async {
      await c.storage.resolve('yeni.txt').writeAsString('merhaba');
      server.emit(const FileUploaded('yeni.txt', 7));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('yeni.txt alındı'), findsOneWidget);
    expect(find.byKey(const ValueKey('file-yeni.txt')), findsOneWidget);
  });
}
