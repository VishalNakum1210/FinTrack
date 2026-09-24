import 'package:fin_track/profile_pages/feedback_page.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FriendProvider friendProvider;

  setUp(() {
    friendProvider = FriendProvider();
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
      ],
      child: const MaterialApp(
        home: FeedbackPage(),
      ),
    );
  }

  group('FeedbackPage Widget Tests', () {
    testWidgets('renders all feedback form elements properly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Header and description
      expect(find.text("Feedback & Support"), findsOneWidget);
      expect(find.text("We Value Your Voice"), findsOneWidget);

      // Star rating
      expect(find.text("Rate Your FinTrack Experience"), findsOneWidget);

      // Form sections
      expect(find.text("FEEDBACK DETAILS"), findsOneWidget);
      expect(find.text("Category"), findsOneWidget);
      expect(find.text("Suggestion"), findsOneWidget);
      expect(find.text("Your Message"), findsOneWidget);
      expect(find.text("Contact Email (Optional)"), findsOneWidget);

      // Submit button
      expect(find.text("Submit Feedback"), findsOneWidget);
    });

    testWidgets('empty feedback message does not proceed to submit', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final submitBtn = find.text("Submit Feedback");
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      // Button should still say Submit Feedback (not loading)
      expect(find.text("Submit Feedback"), findsOneWidget);
      // Dialog should not appear
      expect(find.text("Thank You!"), findsNothing);
    });

    testWidgets('invalid email prevents submission', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter message
      final msgFinder = find.byType(TextField).first;
      await tester.ensureVisible(msgFinder);
      await tester.enterText(msgFinder, "Great app!");
      await tester.pump();

      // Enter invalid email
      final emailFinder = find.byType(TextField).last;
      await tester.ensureVisible(emailFinder);
      await tester.enterText(emailFinder, "invalid-email-format");
      await tester.pump();

      final submitBtn = find.text("Submit Feedback");
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();

      // Dialog should not appear
      expect(find.text("Thank You!"), findsNothing);
    });
  });
}
