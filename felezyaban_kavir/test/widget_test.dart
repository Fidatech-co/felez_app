import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:felezyaban_kavir/data/repository.dart';
import 'package:felezyaban_kavir/main.dart';

void main() {
  testWidgets('Shows login screen', (tester) async {
    final repository = AppRepository(baseUrl: 'https://api.felezyaban.com');
    await tester.pumpWidget(FelezyabanApp(repository: repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('loginUsernameField')), findsOneWidget);
    expect(find.byKey(const ValueKey('loginPasswordField')), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
