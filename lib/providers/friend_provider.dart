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
    _connectivitySub = FirebaseDatabase.instance.ref(".info/connected").onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? true;
      if (_isOffline != !connected) {
        _isOffline = !connected;
        notifyListeners();
      }
    });
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
  Future<bool> addFriend({
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
        return true;
      }

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
      }

      await dbRef.update(multiPathUpdates);

      // Adjust ledgers for all friends
      for (final friendNumber in friendNumbers) {
        if (friendNumber.isEmpty) continue;
        final friendRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
        if (categoryType == "Take Money From Friend") {
          await _atomicUpdateLedger(friendRef, "total_give", parsedAmount);
        } else {
          await _atomicUpdateLedger(friendRef, "total_get", parsedAmount);
        }
      }

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

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
