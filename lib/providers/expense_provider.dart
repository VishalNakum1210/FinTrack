import 'package:fin_track/utils/date_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ExpenseProvider extends ChangeNotifier {
  bool _isLoading = false;
  final List<Map<String, dynamic>> _records = [];

  int _spentCash = 0;
  int _spentOnline = 0;
  int _addCash = 0;
  int _addOnline = 0;

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get records => _records;
  int get spentCash => _spentCash;
  int get spentOnline => _spentOnline;
  int get addCash => _addCash;
  int get addOnline => _addOnline;

  int get totalIncome => _addCash + _addOnline;
  int get totalExpense => _spentCash + _spentOnline;
  int get currentBalance => totalIncome - totalExpense;

  Map<String, int> get categoryTotals {
    final totals = <String, int>{};
    for (var r in _records) {
      final mode = (r["Payment_Mode"] ?? "").toString();
      if (mode.startsWith("Add")) continue;
      final cat = (r["Category"] ?? "Other").toString();
      final amount = (double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0).round();
      totals[cat] = (totals[cat] ?? 0) + amount;
    }
    return totals;
  }

  /// Fetches all expense records for the user and calculates totals
  Future<void> fetchExpenses(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final ref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber");
      final event = await ref.once();

      _records.clear();
      _spentCash = 0;
      _spentOnline = 0;
      _addCash = 0;
      _addOnline = 0;

      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        data.forEach((key, value) {
          if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            map['key'] = key;
            map['_parsedDate'] = DateHelper.parse(map["Date"]);
            _records.add(map);

            final mode = (map["Payment_Mode"] ?? "").toString();
            final amount = (double.tryParse(map["Amount"]?.toString() ?? '0') ?? 0.0).round();

            if (mode == "Spent Cash") {
              _spentCash += amount;
            } else if (mode == "Spent Online") {
              _spentOnline += amount;
            } else if (mode == "Add CASH") {
              _addCash += amount;
            } else if (mode == "Add Online") {
              _addOnline += amount;
            }
          }
        });

        // Fast sort primarily by pre-parsed transaction Date (descending), secondarily by timestamp
        _records.sort((a, b) {
          final DateTime? dateA = a["_parsedDate"] as DateTime?;
          final DateTime? dateB = b["_parsedDate"] as DateTime?;

          if (dateA != null && dateB != null) {
            final dateCmp = dateB.compareTo(dateA);
            if (dateCmp != 0) return dateCmp;
          } else if (dateA != null) {
            return -1;
          } else if (dateB != null) {
            return 1;
          }

          final tA = (a["timestamp"] as num?)?.toInt() ?? 0;
          final tB = (b["timestamp"] as num?)?.toInt() ?? 0;
          return tB.compareTo(tA);
        });
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  /// Adds a new expense record to Firebase and updates local state
  Future<bool> addExpense({
    required String phoneNumber,
    required String amount,
    required String description,
    required String paymentMode,
    required String date,
    required String category,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber");
      final key = ref.push().key!;

      await ref.child(key).set({
        "key": key,
        "Amount": amount,
        "Description": description,
        "Payment_Mode": paymentMode,
        "Date": date,
        "Category": category,
        "timestamp": ServerValue.timestamp,
      });

      await fetchExpenses(phoneNumber);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes an expense record and refreshes state
  Future<bool> deleteExpense({
    required String phoneNumber,
    required String key,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber/$key");
      await ref.remove();
      await fetchExpenses(phoneNumber);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns records filtered by category / mode
  List<Map<String, dynamic>> getFilteredRecords(String filterType) {
    if (filterType == "All") return _records;

    return _records.where((r) {
      if (filterType == "Spent Cash" ||
          filterType == "Spent Online" ||
          filterType == "Add CASH" ||
          filterType == "Add Online") {
        return r["Payment_Mode"] == filterType;
      }
      return r["Category"] == filterType;
    }).toList();
  }

  /// Calculates total for a specific filter
  int getTotalForFilter(String filterType) {
    if (filterType == "All") return totalExpense;
    if (filterType == "Spent Cash") return spentCash;
    if (filterType == "Spent Online") return spentOnline;
    if (filterType == "Add CASH") return addCash;
    if (filterType == "Add Online") return addOnline;

    int total = 0;
    for (var r in _records) {
      if (r["Category"] == filterType) {
        total += (double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0).round();
      }
    }
    return total;
  }

  /// Clears expenses on logout
  void clearExpenses() {
    _records.clear();
    _spentCash = 0;
    _spentOnline = 0;
    _addCash = 0;
    _addOnline = 0;
    notifyListeners();
  }
}
