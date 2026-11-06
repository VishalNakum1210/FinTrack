import 'package:fin_track/widgets/creator_credit.dart';
import 'package:fin_track/app_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:fin_track/profile_pages/terms_and_privacy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('about credit exposes bundled Poppins license', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreatorCredit())),
    );
    await tester.tap(find.text('About FinTrack & licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('Support: daku.9705@gmail.com'), findsOneWidget);
    registerAppLicenses();
    final entries = await tester.runAsync(() => LicenseRegistry.licenses.toList());
    expect(
      entries!.where((entry) => entry.packages.contains('Poppins')),
      isNotEmpty,
    );
  });
  for (final scale in [1.0, 1.8]) {
    testWidgets('creator credit fits a narrow screen at $scale scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(274, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: CreatorCredit()),
        ),
      );
      expect(find.text('Created by Vishal Nakum'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('privacy includes actual data, retention and support', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TermsAndPrivacyPage(initialTabIndex: 1)),
    );
    expect(find.textContaining('optional profile address'), findsOneWidget);
    expect(find.textContaining('no automatic expiry'), findsOneWidget);
    expect(find.textContaining('daku.9705@gmail.com'), findsOneWidget);
    expect(find.text('Created by Vishal Nakum'), findsOneWidget);
  });
}
