// Regression: an "Undo" snackbar (which Flutter persists by default when it
// has an action) must time out instead of following the user to the Result.
import 'package:docukit/core/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showAppSnack with an action still auto-dismisses', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSnack(context, 'Page deleted', actionLabel: 'Undo', onAction: () {}),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('Page deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Page deleted'), findsNothing);
  });
}
