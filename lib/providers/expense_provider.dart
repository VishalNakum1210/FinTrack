import 'dart:async';
import 'package:fin_track/utils/money.dart';
import 'package:fin_track/utils/input_validator.dart';
import 'package:fin_track/services/retry_safe_writer.dart';
import 'package:fin_track/services/split_integrity.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ExpenseProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = "";
  String? lastError;
  String _currentPhoneNumber = "";
  StreamSubscription<DatabaseEvent>? _subscription;

  final List<Map<String, dynamic>> _records = [];

  int _spentCash = 0;
  int _spentOnline = 0;
  int _addCash = 0;
  int _addOnline = 0;
  int _owed = 0;

  int _highestTransaction = 0;
  String _biggestCategory = "No Data";
  int _biggestCategoryAmount = 0;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get records => List.unmodifiable(_records);
  double get spentCash => _spentCash / 100;
  double get spentOnline => _spentOnline / 100;
  double get addCash => _addCash / 100;
  double get addOnline => _addOnline / 100;

  double get totalIncome => (_addCash + _addOnline) / 100;
  double get totalExpense => (_spentCash + _spentOnline + _owed) / 100;
  double get currentBalance =>
      ((_addCash + _addOnline) - (_spentCash + _spentOnline + _owed)) / 100;
  double get cashBalance => (_addCash - _spentCash) / 100;
  double get onlineBalance => (_addOnline - _spentOnline) / 100;
  double get highestTransaction => _highestTransaction / 100;
  String get biggestCategory => _biggestCategory;
  double get biggestCategoryAmount => _biggestCategoryAmount / 100;

  Map<String, double> get categoryTotals {
    final totals = <String, int>{};
    for (var r in _records) {
      final mode = (r["Payment_Mode"] ?? "").toString();
      if (mode.startsWith("Add")) continue;
      final cat = (r["Category"] ?? "Other").toString();
      final amount = Money.paise(r["Amount"]);
      totals[cat] = (totals[cat] ?? 0) + amount;
    }
    return totals.map((category, paise) => MapEntry(category, paise / 100));
  }

  /// Pre-sorted transactions by date descending
  List<Map<String, dynamic>> get sortedRecords {
    final list = List<Map<String, dynamic>>.from(_records);
    list.sort((a, b) {
      final DateTime? dA =
          a['_parsedDate'] as DateTime? ?? DateHelper.parse(a['Date']);
      final DateTime? dB =
          b['_parsedDate'] as DateTime? ?? DateHelper.parse(b['Date']);
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
      return desc.contains(q) ||
          cat.contains(q) ||
          amt.contains(q) ||
          mode.contains(q);
    }).toList();

    results.sort((a, b) {
      final DateTime? dA =
          a['_parsedDate'] as DateTime? ?? DateHelper.parse(a['Date']);
      final DateTime? dB =
          b['_parsedDate'] as DateTime? ?? DateHelper.parse(b['Date']);
      if (dA != null && dB != null) return dB.compareTo(dA);
      return 0;
    });
    return results;
  }

  /// Sets up a real-time stream listener for user expenses
  Future<void> fetchExpenses(String phoneNumber, {bool force = false}) async {
    if (!InputValidator.phone(phoneNumber)) return;

    // If already listening to this phone and not forced or in error, do nothing
    if (_currentPhoneNumber == phoneNumber &&
        _subscription != null &&
        !force &&
        !_hasError) {
      return;
    }

    if (_currentPhoneNumber != phoneNumber) {
      _records.clear();
      _recalculateDerivedTotals();
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
          _errorMessage =
              "Unable to sync expenses. Check your internet connection.";
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
      _owed = 0;
      final data = snapshot.value as Map;
      data.forEach((key, value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          map['key'] = key;
          map['_parsedDate'] = DateHelper.parse(map["Date"]);
          _records.add(map);

          final mode = (map["Payment_Mode"] ?? "").toString();
          final amount = Money.paise(map["Amount"]);

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
      _owed = 0;
      _highestTransaction = 0;
      _biggestCategory = "No Data";
      _biggestCategoryAmount = 0;
    }
  }

  void _recalculateDerivedTotals() {
    _owed = 0;
    _spentCash = 0;
    _spentOnline = 0;
    _addCash = 0;
    _addOnline = 0;

    for (final map in _records) {
      final mode = (map["Payment_Mode"] ?? "").toString();
      final amount = Money.paise(map["Amount"]);
      if (mode == "Spent Cash") {
        _spentCash += amount;
      } else if (mode == "Spent Online") {
        _spentOnline += amount;
      } else if (mode == "Add CASH") {
        _addCash += amount;
      } else if (mode == "Add Online") {
        _addOnline += amount;
      } else if (mode == 'Owed' || mode.startsWith('Owed to ')) {
        _owed += amount;
      }
    }

    _highestTransaction = 0;
    _biggestCategory = "No Data";
    _biggestCategoryAmount = 0;

    final catTotals = <String, int>{};
    for (final record in _records) {
      if (record['Payment_Mode'].toString().startsWith('Add')) continue;
      final category = (record['Category'] ?? 'Other').toString();
      catTotals[category] =
          (catTotals[category] ?? 0) + Money.paise(record['Amount']);
    }
    catTotals.forEach((cat, amount) {
      if (amount > _biggestCategoryAmount) {
        _biggestCategoryAmount = amount;
        _biggestCategory = cat;
      }
    });

    for (var r in _records) {
      final mode = (r["Payment_Mode"] ?? "").toString();
      final amount = Money.paise(r["Amount"]);
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
    String? intentId,
  }) async {
    lastError = null;
    if (!InputValidator.phone(phoneNumber)) {
      lastError = "Invalid phone number";
      return false;
    }
    if (!Money.positive(amount)) {
      lastError = "Please enter a valid amount";
      return false;
    }
    if (!InputValidator.description(description)) {
      lastError = "Description must be between 1 and 500 characters";
      return false;
    }
    if (!InputValidator.mode(paymentMode)) {
      lastError = "Invalid payment mode";
      return false;
    }
    if (!InputValidator.date(date)) {
      lastError = "Transaction date cannot be in the future or invalid";
      return false;
    }
    if (!InputValidator.categories.contains(category)) {
      lastError = "Invalid category";
      return false;
    }
    final success = await RetrySafeWriter.instance.write(
      phoneNumber,
      'expense',
      [
        Money.decimal(Money.paise(amount)),
        description,
        paymentMode,
        InputValidator.normalizedDate(date),
        category,
      ],
      (key) => {
        'Expenses/$phoneNumber/$key': {
          'key': key,
          'Amount': Money.decimal(Money.paise(amount)),
          'Description': description,
          'Payment_Mode': paymentMode,
          'Date': InputValidator.normalizedDate(date),
          ...InputValidator.dateFields(date),
          'Category': category,
          'timestamp': ServerValue.timestamp,
        },
      },
      intentId: intentId,
    );
    if (!success) {
      lastError = RetrySafeWriter.instance.failureMessage;
    }
    return success;
  }

  Future<bool> deleteExpense({
    required String phoneNumber,
    required String key,
  }) async {
    if (!InputValidator.phone(phoneNumber) || !InputValidator.key(key)) {
      return false;
    }

    // ── FIX H3: Optimistic UI update with full rollback on Firebase failure ──
    Map<String, dynamic>? backup;
    int removedIdx = -1;

    try {
      final splitPaths = await SplitIntegrity.load(phoneNumber, key);
      if (splitPaths.isNotEmpty) {
        await FirebaseDatabase.instance.ref().update({
          for (final path in splitPaths) path: null,
        });
        return true;
      }
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
        if (!_records.any((r) => r['key'] == key)) {
          _records.insert(removedIdx.clamp(0, _records.length), backup);
        }
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
    lastError = null;
    if (!InputValidator.phone(phoneNumber)) {
      lastError = "Invalid phone number";
      return false;
    }
    if (!InputValidator.key(key)) {
      lastError = "Invalid record key";
      return false;
    }
    if (!Money.positive(amount)) {
      lastError = "Please enter a valid amount";
      return false;
    }
    if (!InputValidator.description(description)) {
      lastError = "Description must be between 1 and 500 characters";
      return false;
    }
    if (!InputValidator.mode(paymentMode)) {
      lastError = "Invalid payment mode";
      return false;
    }
    if (!InputValidator.date(date)) {
      lastError = "Transaction date cannot be in the future or invalid";
      return false;
    }
    if (!InputValidator.categories.contains(category)) {
      lastError = "Invalid category";
      return false;
    }
    try {
      lastError = null;
      final ref = FirebaseDatabase.instance.ref('Expenses/$phoneNumber/$key');
      final record = (await ref.get().timeout(
        const Duration(seconds: 15),
      )).value;
      if (record is! Map) return false;
      final splitPaths = await SplitIntegrity.load(
        phoneNumber,
        key,
        splitId: record['split_id']?.toString(),
      );
      if (splitPaths.isNotEmpty &&
          (Money.paise(record['Amount']) != Money.paise(amount) ||
              ((record['Payment_Mode'] ?? '').toString().startsWith('Owed to ')
                      ? 'Owed'
                      : record['Payment_Mode']) !=
                  paymentMode)) {
        lastError =
            'Split amounts and payment modes cannot be changed independently. Delete the split and record the corrected bill.';
        return false;
      }
      await FirebaseDatabase.instance.ref('Expenses/$phoneNumber/$key').update({
        'Amount': Money.decimal(Money.paise(amount)),
        'Category': category,
        'Payment_Mode': paymentMode,
        'Description': description,
        'Date': InputValidator.normalizedDate(date),
        ...InputValidator.dateFields(date),
      });
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission-denied') ||
          errorStr.contains('permission_denied') ||
          errorStr.contains('permission denied')) {
        lastError =
            'Permission denied. Please verify your account sign-in or database rules.';
      } else {
        lastError = 'Unable to update expense. Check your connection.';
      }
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
  double getTotalForFilter(String filterType) {
    if (filterType == "All") return totalExpense;
    if (filterType == "Spent Cash") return spentCash;
    if (filterType == "Spent Online") return spentOnline;
    if (filterType == "Add CASH") return addCash;
    if (filterType == "Add Online") return addOnline;

    int total = 0;
    for (var r in _records) {
      if (r["Category"] == filterType) {
        total += Money.paise(r["Amount"]);
      }
    }
    return total / 100;
  }

  /// Clears expenses on logout
  void clearExpenses() {
    _owed = 0;
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
    _recalculateDerivedTotals();
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
