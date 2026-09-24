import 'package:fin_track/profile_pages/terms_and_privacy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest({int initialTab = 0}) {
    return MaterialApp(
      home: TermsAndPrivacyPage(initialTabIndex: initialTab),
    );
  }

  group('TermsAndPrivacyPage Widget Tests', () {
    testWidgets('renders header, segmented tabs and initial terms content', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Terms & Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Disclaimers'), findsOneWidget);

      // Section 1 of Terms should be visible initially
      expect(find.text('1. Acceptance of Terms'), findsOneWidget);
      expect(find.text('2. Scope of Service'), findsOneWidget);
    });

    testWidgets('switching to Privacy Policy tab displays privacy sections', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Privacy Policy tab
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('1. Information We Collect'), findsOneWidget);
      expect(find.text('2. Cloud Storage & Data Security'), findsOneWidget);
      expect(find.text('3. Zero Advertising & No Data Selling'), findsOneWidget);
    });

    testWidgets('switching to Disclaimers tab displays disclaimer sections', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Disclaimers tab
      await tester.tap(find.text('Disclaimers'));
      await tester.pumpAndSettle();

      expect(find.text('1. Not a Banking / Financial Institution'), findsOneWidget);
      expect(find.text('2. No Professional Financial Advice'), findsOneWidget);
    });
  });
}
