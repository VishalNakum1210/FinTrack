import 'dart:async';
import 'package:fin_track/utils/date_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ExpenseProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = "";
  String _currentPhoneNumber = "";
  StreamSubscription<DatabaseEvent>? _subscription;

  final List<Map<String, dynamic>> _records = [];

  int _spentCash = 0;
  int _spentOnline = 0;
  int _addCash = 0;
  int _addOnline = 0;

  int _highestTransaction = 0;
  String _biggestCategory = "No Data";
  int _biggestCategoryAmount = 0;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get records => List.unmodifiable(_records);
  int get spentCash => _spentCash;
  int get spentOnline => _spentOnline;
  int get addCash => _addCash;
  int get addOnline => _addOnline;

  int get totalIncome => _addCash + _addOnline;
  int get totalExpense => _spentCash + _spentOnline;
  int get currentBalance => totalIncome - totalExpense;
  int get cashBalance => _addCash - _spentCash;
  int get onlineBalance => _addOnline - _spentOnline;
  int get highestTransaction => _highestTransaction;
  String get biggestCategory => _biggestCategory;
  int get biggestCategoryAmount => _biggestCategoryAmount;

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

  /// Pre-sorted transactions by date descending
  List<Map<String, dynamic>> get sortedRecords {
    final list = List<Map<String, dynamic>>.from(_records);
    list.sort((a, b) {
      final DateTime? dA = a['_parsedDate'] as DateTime? ?? DateHelper.parse(a['Date']);
      final DateTime? dB = b['_parsedDate'] as DateTime? ?? DateHelper.parse(b['Date']);
      if (dA != null && dB != null) {
        final c = dB.compareTo(dA);
        if (c != 0) return c;
      } else if (dA != null) {
        return -1;
      } else if (dB != null) {
        return 1;
      }
      final tA = (a['timestamp'] as num?)?.toInt() ?? 0;
      final tB = (b['timestamp'] as num?)?.toInt() ?? 0;
      return tB.compareTo(tA);
    });
    return List.unmodifiable(list);
  }

  /// Searches transactions matching description, category, payment mode or amount
  List<Map<String, dynamic>> searchRecords(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return sortedRecords;
    final results = _records.where((r) {
      final desc = (r['Description'] ?? '').toString().toLowerCase();
      final cat = (r['Category'] ?? '').toString().toLowerCase();
      final amt = (r['Amount'] ?? '').toString();
      final mode = (r['Payment_Mode'] ?? '').toString().toLowerCase();
      return desc.contains(q) || cat.contains(q) || amt.contains(q) || mode.contains(q);
    }).toList();

    results.sort((a, b) {
      final DateTime? dA = a['_parsedDate'] as DateTime? ?? DateHelper.parse(a['Date']);
      final DateTime? dB = b['_parsedDate'] as DateTime? ?? DateHelper.parse(b['Date']);
      if (dA != null && dB != null) return dB.compareTo(dA);
      return 0;
    });
    return results;
  }

  /// Sets up a real-time stream listener for user expenses
  Future<void> fetchExpenses(String phoneNumber, {bool force = false}) async {
    if (phoneNumber.isEmpty) return;

    // If already listening to this phone and not forced or in error, do nothing
    if (_currentPhoneNumber == phoneNumber && _subscription != null && !force && !_hasError) {
      return;
    }

    _currentPhoneNumber = phoneNumber;
    _isLoading = true;
    _hasError = false;
    _errorMessage = "";
    notifyListeners();

    await _subscription?.cancel();

    try {
      final ref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber");

      _subscription = ref.onValue.listen(
        (event) {
          _processSnapshot(event.snapshot);
          _isLoading = false;
          _hasError = false;
          _errorMessage = "";
          notifyListeners();
        },
        onError: (error) {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "Unable to sync expenses. Check your internet connection.";
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = "Connection error. Please try again.";
      notifyListeners();
    }
  }

  void _processSnapshot(DataSnapshot snapshot) {
    _records.clear();
    _spentCash = 0;
    _spentOnline = 0;
    _addCash = 0;
    _addOnline = 0;

    if (snapshot.value != null && snapshot.value is Map) {
      final data = snapshot.value as Map;
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

      _recalculateDerivedTotals();
    } else {
      _highestTransaction = 0;
      _biggestCategory = "No Data";
      _biggestCategoryAmount = 0;
    }
  }

  void _recalculateDerivedTotals() {
    _spentCash = 0;
    _spentOnline = 0;
    _addCash = 0;
    _addOnline = 0;

    for (final map in _records) {
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

    _highestTransaction = 0;
    _biggestCategory = "No Data";
    _biggestCategoryAmount = 0;

    final catTotals = categoryTotals;
    catTotals.forEach((cat, amount) {
      if (amount > _biggestCategoryAmount) {
        _biggestCategoryAmount = amount;
        _biggestCategory = cat;
      }
    });

    for (var r in _records) {
      final mode = (r["Payment_Mode"] ?? "").toString();
      final amount = (double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0).round();
      if (!mode.startsWith("Add") && amount > _highestTransaction) {
        _highestTransaction = amount;
      }
    }
  }

  Future<bool> addExpense({
    required String phoneNumber,
    required String amount,
    required String description,
    required String paymentMode,
    required String date,
    required String category,
  }) async {
    if (phoneNumber.isEmpty) return false;
    try {
      final ref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber");
      final key = ref.push().key;
      if (key == null || key.isEmpty) return false;

      await ref.child(key).set({
        "key": key,
        "Amount": amount,
        "Description": description,
        "Payment_Mode": paymentMode,
        "Date": date,
        "Category": category,
        "timestamp": ServerValue.timestamp,
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteExpense({
    required String phoneNumber,
    required String key,
  }) async {
    if (phoneNumber.isEmpty || key.isEmpty) return false;

    // ── FIX H3: Optimistic UI update with full rollback on Firebase failure ──
    Map<String, dynamic>? backup;
    int removedIdx = -1;

    try {
      removedIdx = _records.indexWhere((r) => r['key'] == key);
      if (removedIdx != -1) {
        // Save a deep copy for potential rollback
        backup = Map<String, dynamic>.from(_records[removedIdx]);
        _records.removeAt(removedIdx);
        _recalculateDerivedTotals();
        notifyListeners();
      }

      final ref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber/$key");
      await ref.remove();
      return true;
    } catch (_) {
      // Firebase failed — roll back the optimistic removal
      if (backup != null && removedIdx != -1) {
        _records.insert(removedIdx, backup);
        _recalculateDerivedTotals();
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateExpense({
    required String phoneNumber,
    required String key,
    required String amount,
    required String category,
    required String paymentMode,
    required String description,
    required String date,
  }) async {
    if (phoneNumber.isEmpty || key.isEmpty) return false;
    try {
      // Optimistically update local record list so all consumers update immediately
      final idx = _records.indexWhere((r) => r['key'] == key);
      if (idx != -1) {
        _records[idx]['Amount'] = amount;
        _records[idx]['Category'] = category;
        _records[idx]['Payment_Mode'] = paymentMode;
        _records[idx]['Description'] = description;
        _records[idx]['Date'] = date;
        _records[idx]['_parsedDate'] = DateHelper.parse(date);
        _recalculateDerivedTotals();
        notifyListeners();
      }

      final ref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber/$key");
      await ref.update({
        "Amount": amount,
        "Category": category,
        "Payment_Mode": paymentMode,
        "Description": description,
        "Date": date,
      });
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
    _subscription?.cancel();
    _subscription = null;
    _currentPhoneNumber = "";
    _records.clear();
    _spentCash = 0;
    _spentOnline = 0;
    _addCash = 0;
    _addOnline = 0;
    _highestTransaction = 0;
    _biggestCategory = "No Data";
    _biggestCategoryAmount = 0;
    _isLoading = false;
    _hasError = false;
    _errorMessage = "";
    notifyListeners();
  }

  @visibleForTesting
  void setRecordsForTesting(List<Map<String, dynamic>> records) {
    _records.clear();
    _records.addAll(records);
    _isLoading = false;
    _hasError = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
