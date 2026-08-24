import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      final amount = int.tryParse(r["Amount"]?.toString() ?? '0') ?? 0;
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
            _records.add(map);

            final mode = (map["Payment_Mode"] ?? "").toString();
            final amount = int.tryParse(map["Amount"]?.toString() ?? '0') ?? 0;

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

        // Sort descending by date/timestamp
        _records.sort((a, b) {
          final tA = a["timestamp"] is int ? a["timestamp"] as int : 0;
          final tB = b["timestamp"] is int ? b["timestamp"] as int : 0;
          if (tA != 0 && tB != 0) return tB.compareTo(tA);

          try {
            final fA = DateFormat('d/M/yyyy').parse(a["Date"] ?? '');
            final fB = DateFormat('d/M/yyyy').parse(b["Date"] ?? '');
            return fB.compareTo(fA);
          } catch (_) {
            return 0;
          }
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
        total += int.tryParse(r["Amount"]?.toString() ?? '0') ?? 0;
      }
    }
    return total;
  }
}
