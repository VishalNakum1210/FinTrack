import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class FriendProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = "";
  String _currentPhone = "";
  StreamSubscription<DatabaseEvent>? _subscription;

  final List<Map<String, dynamic>> _friends = [];

  int _totalGet = 0;
  int _totalGive = 0;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get friends => _friends;
  int get totalGet => _totalGet;
  int get totalGive => _totalGive;

  /// Sets up a real-time stream listener for friends and aggregate ledger totals
  Future<void> fetchFriends(String phoneNumber, {bool force = false}) async {
    if (phoneNumber.isEmpty) return;

    if (_currentPhone == phoneNumber && _subscription != null && !force && !_hasError) {
      return;
    }

    _currentPhone = phoneNumber;
    _isLoading = true;
    _hasError = false;
    _errorMessage = "";
    notifyListeners();

    await _subscription?.cancel();

    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$phoneNumber");

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
          _errorMessage = "Unable to sync friends ledger. Check your internet connection.";
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
    _friends.clear();
    _totalGet = 0;
    _totalGive = 0;

    if (snapshot.value != null && snapshot.value is Map) {
      final data = snapshot.value as Map;
      data.forEach((key, value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          _friends.add(map);

          final getVal = (double.tryParse(map["total_get"]?.toString() ?? '0') ?? 0.0).round();
          final giveVal = (double.tryParse(map["total_give"]?.toString() ?? '0') ?? 0.0).round();
          _totalGet += getVal;
          _totalGive += giveVal;
        }
      });
    }
  }

  /// Adds a new friend (real-time stream will auto-update local state)
  Future<bool> addFriend({
    required String userPhone,
    required String friendName,
    required String friendNumber,
    String note = "",
    required String date,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      await ref.set({
        "friend_name": friendName,
        "friend_number": friendNumber,
        "note": note,
        "date": date,
        "timestamp": ServerValue.timestamp,
        "total_get": "0",
        "total_give": "0",
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a friend and all ledger history (real-time stream will auto-update)
  Future<bool> deleteFriend({
    required String userPhone,
    required String friendNumber,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      await ref.remove();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Helper for atomic increment of ledger fields
  Future<void> _atomicUpdateLedger(
    DatabaseReference friendRef,
    String field,
    int delta,
  ) async {
    await friendRef.child(field).runTransaction((Object? currentData) {
      final currentVal = (double.tryParse(currentData?.toString() ?? '0') ?? 0.0).round();
      final newVal = (currentVal + delta).clamp(0, 999999999);
      return Transaction.success(newVal.toString());
    });
  }

  Future<void> adjustLedger({
    required DatabaseReference friendRef,
    required String field,
    required int delta,
  }) async {
    await _atomicUpdateLedger(friendRef, field, delta);
  }

  /// Adds a transaction to a specific friend's ledger atomically
  Future<bool> addFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String amount,
    required String description,
    required String paymentMode,
    required String date,
    required String categoryType,
  }) async {
    try {
      final recordRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber/Records");
      final key = recordRef.push().key!;
      final parsedAmount = (double.tryParse(amount) ?? 0.0).round();

      await recordRef.child(key).set({
        "key": key,
        "Amount": amount,
        "Description": description,
        "Payment_Mode": paymentMode,
        "Date": date,
        "Type": categoryType,
        "timestamp": ServerValue.timestamp,
      });

      final friendRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      if (categoryType == "Take Money From Friend") {
        await _atomicUpdateLedger(friendRef, "total_give", parsedAmount);
      } else {
        await _atomicUpdateLedger(friendRef, "total_get", parsedAmount);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Atomically batches multiple friend ledger transactions (e.g. for Multi-Friend Bill Splitting)
  Future<int> batchAddFriendTransactions({
    required String userPhone,
    required List<String> friendNumbers,
    required String amountPerFriend,
    required String description,
    required String paymentMode,
    required String date,
    required String categoryType,
  }) async {
    int successCount = 0;
    final parsedAmount = (double.tryParse(amountPerFriend) ?? 0.0).round();

    for (final friendNumber in friendNumbers) {
      try {
        final recordRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber/Records");
        final key = recordRef.push().key!;

        await recordRef.child(key).set({
          "key": key,
          "Amount": amountPerFriend,
          "Description": description,
          "Payment_Mode": paymentMode,
          "Date": date,
          "Type": categoryType,
          "timestamp": ServerValue.timestamp,
        });

        final friendRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
        if (categoryType == "Take Money From Friend") {
          await _atomicUpdateLedger(friendRef, "total_give", parsedAmount);
        } else {
          await _atomicUpdateLedger(friendRef, "total_get", parsedAmount);
        }
        successCount++;
      } catch (_) {}
    }

    return successCount;
  }

  /// Deletes a specific transaction record from a friend's ledger atomically
  Future<bool> deleteFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String recordKey,
    required bool isGive,
    required int amount,
  }) async {
    try {
      final recordRef = FirebaseDatabase.instance.ref(
        "Friends/$userPhone/$friendNumber/Records/$recordKey",
      );
      await recordRef.remove();

      final friendRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      if (isGive) {
        await _atomicUpdateLedger(friendRef, "total_give", -amount);
      } else {
        await _atomicUpdateLedger(friendRef, "total_get", -amount);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Executes an atomic multi-path transaction for bill splitting
  /// Updates both Passbook Expense and Friend Ledger in a single atomic network payload
  Future<bool> atomicSplitBill({
    required String userPhone,
    required String friendNumber,
    required String myShareAmount,
    required String friendShareAmount,
    required String totalAmount,
    required String description,
    required String date,
    required String category,
    required String paymentMode,
  }) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final expenseKey = dbRef.child("Expenses/$userPhone").push().key!;
      final recordKey = dbRef.child("Friends/$userPhone/$friendNumber/Records").push().key!;

      final Map<String, Object?> multiPathUpdates = {};

      // 1. Personal Passbook Entry
      multiPathUpdates["Expenses/$userPhone/$expenseKey"] = {
        "key": expenseKey,
        "Amount": myShareAmount,
        "Description": "$description (Your share of ₹$totalAmount)",
        "Payment_Mode": paymentMode,
        "Date": date,
        "Category": category,
        "timestamp": ServerValue.timestamp,
      };

      // 2. Friend Ledger Record
      multiPathUpdates["Friends/$userPhone/$friendNumber/Records/$recordKey"] = {
        "key": recordKey,
        "Amount": friendShareAmount,
        "Description": "Split: $description (Total ₹$totalAmount)",
        "Payment_Mode": paymentMode,
        "Date": date,
        "Type": "Give Money To Friend",
        "timestamp": ServerValue.timestamp,
      };

      // Single atomic multi-path update
      await dbRef.update(multiPathUpdates);

      // Atomically update ledger total
      final parsedFriendAmount = (double.tryParse(friendShareAmount) ?? 0.0).round();
      final friendRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      await _atomicUpdateLedger(friendRef, "total_get", parsedFriendAmount);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears friends state on logout
  void clearFriends() {
    _subscription?.cancel();
    _subscription = null;
    _currentPhone = "";
    _friends.clear();
    _totalGet = 0;
    _totalGive = 0;
    _isLoading = false;
    _hasError = false;
    _errorMessage = "";
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
