import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

enum AddFriendResult {
  added,
  updated,
  failed,
}

class FriendProvider extends ChangeNotifier {
  FriendProvider() {
    _initConnectivity();
  }

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = "";
  String _currentPhone = "";
  StreamSubscription<DatabaseEvent>? _subscription;

  final List<Map<String, dynamic>> _friends = [];

  int _totalGet = 0;
  int _totalGive = 0;
  bool _isOffline = false;
  StreamSubscription<DatabaseEvent>? _connectivitySub;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isOffline => _isOffline;
  String get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get friends => List.unmodifiable(_friends);
  int get totalGet => _totalGet;
  int get totalGive => _totalGive;

  void _initConnectivity() {
    if (_connectivitySub != null) return;
    try {
      _connectivitySub = FirebaseDatabase.instance.ref(".info/connected").onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? true;
        if (_isOffline != !connected) {
          _isOffline = !connected;
          notifyListeners();
        }
      });
    } catch (_) {
      // In tests or environments without Firebase initialized, ignore gracefully
    }
  }

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

    _initConnectivity();
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

  /// Adds a new friend safely without overwriting existing ledger
  Future<AddFriendResult> addFriend({
    required String userPhone,
    required String friendName,
    required String friendNumber,
    String note = "",
    required String date,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      final snapshot = await ref.get();
      if (snapshot.exists) {
        // Friend already exists: update name/note only, preserve existing ledger
        await ref.update({
          "friend_name": friendName,
          "note": note,
        });
        return AddFriendResult.updated;
      }

      await ref.set({
        "friend_name": friendName,
        "friend_number": friendNumber,
        "note": note,
        "date": date,
        "timestamp": ServerValue.timestamp,
        "total_get": 0,
        "total_give": 0,
      });

      return AddFriendResult.added;
    } catch (_) {
      return AddFriendResult.failed;
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
      final calculated = currentVal + delta;
      // Guard against underflow while preserving non-negative aggregate invariant
      final newVal = calculated < 0 ? 0 : calculated;
      return Transaction.success(newVal);
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
    if (userPhone.isEmpty || friendNumber.isEmpty) return false;
    try {
      final recordRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber/Records");
      final key = recordRef.push().key;
      if (key == null || key.isEmpty) return false;
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

  Future<int> batchAddFriendTransactions({
    required String userPhone,
    required List<String> friendNumbers,
    required String amountPerFriend,
    required String description,
    required String paymentMode,
    required String date,
    required String categoryType,
  }) async {
    if (userPhone.isEmpty) return 0;
    int successCount = 0;
    final parsedAmount = (double.tryParse(amountPerFriend) ?? 0.0).round();

    for (final friendNumber in friendNumbers) {
      if (friendNumber.isEmpty) continue;
      try {
        final recordRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber/Records");
        final key = recordRef.push().key;
        if (key == null || key.isEmpty) continue;

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

  Future<bool> deleteFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String recordKey,
    required bool isGive,
    required int amount,
  }) async {
    if (userPhone.isEmpty || friendNumber.isEmpty || recordKey.isEmpty) return false;
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
      final expRef = dbRef.child("Expenses/$userPhone").push();
      final expenseKey = expRef.key ?? DateTime.now().millisecondsSinceEpoch.toString();

      final recRef = dbRef.child("Friends/$userPhone/$friendNumber/Records").push();
      final recordKey = recRef.key ?? (DateTime.now().millisecondsSinceEpoch + 1).toString();

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

      // 3. Atomically update ledger total in the same payload
      final parsedFriendAmount = (double.tryParse(friendShareAmount) ?? 0.0).round();
      multiPathUpdates["Friends/$userPhone/$friendNumber/total_get"] =
          ServerValue.increment(parsedFriendAmount);

      // Single atomic multi-path update
      await dbRef.update(multiPathUpdates);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Performs an atomic multi-path split across multiple friends in a SINGLE network payload
  Future<bool> atomicMultiFriendSplit({
    required String userPhone,
    required List<String> friendNumbers,
    required String amountPerFriend,
    required String description,
    required String paymentMode,
    required String date,
    required String categoryType,
  }) async {
    if (userPhone.isEmpty || friendNumbers.isEmpty) return false;
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final Map<String, Object?> multiPathUpdates = {};
      final parsedAmount = (double.tryParse(amountPerFriend) ?? 0.0).round();
      final ledgerField = categoryType == "Take Money From Friend" ? "total_give" : "total_get";

      for (int i = 0; i < friendNumbers.length; i++) {
        final friendNumber = friendNumbers[i];
        if (friendNumber.isEmpty) continue;
        final newRef = dbRef.child("Friends/$userPhone/$friendNumber/Records").push();
        final key = newRef.key ?? "${DateTime.now().millisecondsSinceEpoch}_$i";

        multiPathUpdates["Friends/$userPhone/$friendNumber/Records/$key"] = {
          "key": key,
          "Amount": amountPerFriend,
          "Description": description,
          "Payment_Mode": paymentMode,
          "Date": date,
          "Type": categoryType,
          "timestamp": ServerValue.timestamp,
        };

        multiPathUpdates["Friends/$userPhone/$friendNumber/$ledgerField"] =
            ServerValue.increment(parsedAmount);
      }

      await dbRef.update(multiPathUpdates);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Executes a single atomic multi-path transaction for bill splitting across user's passbook and all friends.
  /// If ANY part of the write fails, none of the changes are written to the database (H2 fix).
  Future<bool> atomicFullBillSplit({
    required String userPhone,
    required String myShareAmount,
    required String myDescription,
    required String totalAmount,
    required String paymentMode,
    required String category,
    required String date,
    required List<String> friendNumbers,
    required String amountPerFriend,
    required String friendDescription,
    required String categoryType,
  }) async {
    if (userPhone.isEmpty || friendNumbers.isEmpty) return false;
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final Map<String, Object?> multiPathUpdates = {};
      final parsedAmount = (double.tryParse(amountPerFriend) ?? 0.0).round();
      final ledgerField = categoryType == "Take Money From Friend" ? "total_give" : "total_get";

      // 1. Personal Passbook Entry (Atomic part of the multi-path update)
      final expRef = dbRef.child("Expenses/$userPhone").push();
      final expenseKey = expRef.key ?? DateTime.now().millisecondsSinceEpoch.toString();

      multiPathUpdates["Expenses/$userPhone/$expenseKey"] = {
        "key": expenseKey,
        "Amount": myShareAmount,
        "Description": myDescription,
        "Payment_Mode": paymentMode,
        "Date": date,
        "Category": category,
        "timestamp": ServerValue.timestamp,
      };

      // 2. Each friend's record AND their ledger increment, in the SAME payload
      for (int i = 0; i < friendNumbers.length; i++) {
        final friendNumber = friendNumbers[i];
        if (friendNumber.isEmpty) continue;
        final newRef = dbRef.child("Friends/$userPhone/$friendNumber/Records").push();
        final key = newRef.key ?? "${DateTime.now().millisecondsSinceEpoch}_$i";

        multiPathUpdates["Friends/$userPhone/$friendNumber/Records/$key"] = {
          "key": key,
          "Amount": amountPerFriend,
          "Description": friendDescription,
          "Payment_Mode": paymentMode,
          "Date": date,
          "Type": categoryType,
          "timestamp": ServerValue.timestamp,
        };

        // No separate transaction needed — this commits atomically with everything else.
        multiPathUpdates["Friends/$userPhone/$friendNumber/$ledgerField"] =
            ServerValue.increment(parsedAmount);
      }

      // One network call. Either the whole split lands, or none of it does — safe to retry.
      await dbRef.update(multiPathUpdates);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears friends state on logout
  void clearFriends() {
    _subscription?.cancel();
    _subscription = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _currentPhone = "";
    _friends.clear();
    _totalGet = 0;
    _totalGive = 0;
    _isOffline = false;
    _isLoading = false;
    _hasError = false;
    _errorMessage = "";
    notifyListeners();
  }

  @visibleForTesting
  void setFriendsForTesting(
    List<Map<String, dynamic>> friends, {
    int totalGet = 0,
    int totalGive = 0,
  }) {
    _friends.clear();
    _friends.addAll(friends);
    _totalGet = totalGet;
    _totalGive = totalGive;
    _isLoading = false;
    _hasError = false;
    notifyListeners();
  }

  @visibleForTesting
  void setIsOfflineForTesting(bool isOffline) {
    _isOffline = isOffline;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
