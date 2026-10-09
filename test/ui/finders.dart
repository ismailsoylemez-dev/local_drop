import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `FilledButton.icon` gibi alt sınıflar dahil, metni [text] olan buton.
Finder buttonWithText<T extends ButtonStyleButton>(String text) =>
    find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is T),
    );

T buttonWidget<T extends ButtonStyleButton>(WidgetTester tester, String text) =>
    tester.widget<T>(buttonWithText<T>(text).first);
