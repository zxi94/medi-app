import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediscan_ai/widgets/admin_badge.dart';

void main() {
  testWidgets('AdminBadge is hidden when isAdmin is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBadge(isAdmin: false),
        ),
      ),
    );

    expect(find.text('Admin'), findsNothing);
  });

  testWidgets('AdminBadge shows label when isAdmin is true', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBadge(isAdmin: true),
        ),
      ),
    );

    expect(find.text('Admin'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user), findsOneWidget);
  });

  testWidgets('AdminBadge shows loading indicator when loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBadge(isAdmin: false, isLoading: true),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
  });
}
