import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/app.dart';
import 'package:local_drop/state/server_controller.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('ana ekran: başlık, durum metni ve Başlat butonu', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ServerController(),
        child: const LocalDropApp(),
      ),
    );

    expect(find.text('Local Drop'), findsOneWidget);
    expect(find.text('Sunucu kapalı'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Başlat'), findsOneWidget);
  });
}
