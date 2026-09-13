import 'package:fin_track/widgets/insight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InsightCard', () {
    testWidgets('renders icon, title and value correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InsightCard(
              icon: Icons.account_balance_wallet,
              title: 'Total Spent',
              value: '₹5,000',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
      expect(find.text('Total Spent'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);
    });
  });
}
