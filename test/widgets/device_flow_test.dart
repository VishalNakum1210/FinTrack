import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../integration_test/support/device_flow.dart';

void main() {
  testWidgets('QA input helper waits for a delayed field', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FutureBuilder<void>(
            future: Future<void>.delayed(const Duration(milliseconds: 250)),
            builder: (context, state) =>
                state.connectionState == ConnectionState.done
                ? TextField(controller: controller)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await enter(tester, find.byType(TextField), 'ready');
    expect(controller.text, 'ready');
  });

  testWidgets('QA input helper reopens the same field after unfocusing', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: controller, focusNode: focus),
              ElevatedButton(onPressed: () {}, child: const Text('Validate')),
            ],
          ),
        ),
      ),
    );
    await enter(tester, find.byType(TextField), 'first-value');
    expect(focus.hasFocus, isTrue);
    await tapVisible(tester, find.text('Validate'));
    expect(focus.hasFocus, isFalse);
    await enter(tester, find.byType(TextField), 'corrected-value');
    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'corrected-value');
  });
}
