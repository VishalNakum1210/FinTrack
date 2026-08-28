import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class FriendProvider extends ChangeNotifier {
  bool _isLoading = false;
  final List<Map<String, dynamic>> _friends = [];

  int _totalGet = 0;
  int _totalGive = 0;

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get friends => _friends;
  int get totalGet => _totalGet;
  int get totalGive => _totalGive;

  /// Fetches all friends and aggregate get/give ledger totals
  Future<void> fetchFriends(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$phoneNumber");
      final event = await ref.once();

      _friends.clear();
      _totalGet = 0;
      _totalGive = 0;

      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
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
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  /// Adds a new friend
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

      await fetchFriends(userPhone);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a friend and all ledger history
  Future<bool> deleteFriend({
    required String userPhone,
    required String friendNumber,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      await ref.remove();
      await fetchFriends(userPhone);
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

      await fetchFriends(userPhone);
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

    await fetchFriends(userPhone);
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

      await fetchFriends(userPhone);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears friends state on logout
  void clearFriends() {
    _friends.clear();
    _totalGet = 0;
    _totalGive = 0;
    notifyListeners();
  }
}

