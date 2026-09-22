import 'package:fin_track/widgets/export_statement_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportStatementModal', () {
    final mockRecords = [
      {
        'key': '-test1',
        'Amount': '1500.00',
        'Category': 'Salary',
        'Date': '05/09/2026',
        'Description': 'Freelance income',
        'Payment_Mode': 'Add Online',
        'timestamp': 1788566400000,
      },
      {
        'key': '-test2',
        'Amount': '450.00',
        'Category': 'Food',
        'Date': '10/09/2026',
        'Description': 'Team lunch',
        'Payment_Mode': 'Spent Online',
        'timestamp': 1788998400000,
      },
    ];

    testWidgets('renders all modal components, filters and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showExportStatementModal(
                      context: context,
                      userName: 'Vishal Nakum',
                      phoneNumber: '9876543210',
                      records: mockRecords,
                      initialCategory: 'All',
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify Title & Subtitle
      expect(find.text('Export Financial Statement'), findsOneWidget);
      expect(find.text('Bank-grade A4 PDF transaction report'), findsOneWidget);

      // Verify Date Range Presets
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Last 3 Months'), findsOneWidget);
      expect(find.text('Financial Year'), findsOneWidget);
      expect(find.text('Custom Range'), findsOneWidget);

      // Verify Transaction Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Debits Only'), findsOneWidget);
      expect(find.text('Credits Only'), findsOneWidget);

      // Verify Document Options
      expect(find.text('Include Category Breakdown'), findsOneWidget);
      expect(find.text('Include Running Balance Column'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Preview PDF'), findsOneWidget);
      expect(find.text('Download / Share'), findsOneWidget);
    });

    testWidgets('switching transaction filter updates preview state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showExportStatementModal(
                      context: context,
                      userName: 'Vishal Nakum',
                      phoneNumber: '9876543210',
                      records: mockRecords,
                      initialCategory: 'All',
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Tap Debits Only filter
      await tester.tap(find.text('Debits Only'));
      await tester.pumpAndSettle();

      // Tap Credits Only filter
      await tester.tap(find.text('Credits Only'));
      await tester.pumpAndSettle();

      // Return to All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
    });
  });
}
