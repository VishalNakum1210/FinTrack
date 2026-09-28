import 'dart:convert';
import 'package:fin_track/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportService JSON and CSV generation tests', () {
    test('generateJsonBackupString safely serializes DateTime and complex records', () {
      final expenses = [
        {
          'key': 'expense-1',
          'Amount': '750',
          'Category': 'Shopping',
          'Date': '24/09/2026',
          'Payment_Mode': 'Spent Online',
          'Description': 'Shoes & clothes',
          '_parsedDate': DateTime(2026, 9, 24, 14, 30),
          '_runningBalance': 4250.0,
        },
      ];

      final friends = [
        {
          'friend_name': 'Amit',
          'friend_number': '9876543210',
          'total_get': '500',
          'total_give': '0',
          'note': 'Lunch split',
          'transactions': {
            't1': {
              'amount': 500,
              'type': 'give',
              'date': DateTime(2026, 9, 20),
            }
          }
        }
      ];

      // This should NOT throw even with DateTime inside the maps!
      final jsonString = ExportService.generateJsonBackupString(
        userName: 'Vishal Nakum',
        phoneNumber: '9876543210',
        expenses: expenses,
        friends: friends,
      );

      expect(jsonString, isNotEmpty);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['app'], 'FinTrack');
      expect(decoded['version'], '2.2.0');
      expect(decoded['user']['name'], 'Vishal Nakum');
      expect(decoded['total_expenses_count'], 1);
      expect(decoded['total_friends_count'], 1);
      expect(decoded['expenses'], isA<List>());
      expect(decoded['friends'], isA<List>());
    });

    test('generateCsvString correctly formats headers and values', () {
      final expenses = [
        {
          'Amount': '1200',
          'Category': 'Groceries',
          'Date': '24/09/2026',
          'Payment_Mode': 'Spent Cash',
          'Description': 'Weekly "vegetables" & fruits',
          '_runningBalance': 3050.0,
        },
      ];

      final csvString = ExportService.generateCsvString(expenses: expenses);
      expect(csvString, contains('Date,Category,Payment Mode,Amount,Description,Running Balance'));
      expect(csvString, contains('"24/09/2026"'));
      expect(csvString, contains('"Groceries"'));
      expect(csvString, contains('1200'));
      expect(csvString, contains('"Weekly ""vegetables"" & fruits"'));
      expect(csvString, contains('3050.0'));
    });
  });
}
