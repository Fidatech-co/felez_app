// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:felezyaban_kavir/main.dart';

void main() {
  testWidgets('HomeShell renders dashboard and switches tabs', (tester) async {
    await tester.pumpWidget(const FelezyabanApp());

    expect(find.text('نام کاربری یا شماره همراه'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('loginUsernameField')),
      'test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('loginPasswordField')),
      '1',
    );
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد'), findsWidgets);
    expect(find.text('فرم ها'), findsWidgets);
    expect(find.text('وب'), findsWidgets);
    expect(find.text('خوش آمدید، یاسین رحمانی'), findsOneWidget);

    await tester.tap(find.text('فرم ها').last);
    await tester.pumpAndSettle();

    expect(find.text('فرم ثبت دستگاه جدید'), findsOneWidget);

    await tester.tap(find.text('وب').last);
    await tester.pumpAndSettle();

    expect(find.byType(WebViewWidget), findsOneWidget);
  });
}
