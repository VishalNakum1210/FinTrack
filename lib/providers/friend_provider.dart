import 'dart:async';
import 'package:fin_track/services/retry_safe_writer.dart';
import 'package:fin_track/services/split_integrity.dart';
import 'package:fin_track/utils/input_validator.dart';
import 'package:fin_track/utils/ledger_totals.dart';
import 'package:fin_track/utils/money.dart';
import 'package:fin_track/utils/split_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

enum AddFriendResult { added, updated, failed }

class FriendProvider extends ChangeNotifier {
  FriendProvider() {
    _initConnectivity();
  }
  bool _isLoading = false, _hasError = false, _isOffline = false;
  String _errorMessage = '', _currentPhone = '';
  String? _lastError;
  StreamSubscription<DatabaseEvent>? _subscription, _connectivitySub;
  final List<Map<String, dynamic>> _friends = [];
  int _getPaise = 0, _givePaise = 0;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isOffline => _isOffline;
  String get errorMessage => _errorMessage;
  String? get lastError => _lastError;
  List<Map<String, dynamic>> get friends => List.unmodifiable(_friends);
  double get totalGet => _getPaise / 100;
  double get totalGive => _givePaise / 100;

  void _initConnectivity() {
    if (_connectivitySub != null) return;
    try {
      _connectivitySub = FirebaseDatabase.instance
          .ref('.info/connected')
          .onValue
          .listen(
            (event) {
              final offline = event.snapshot.value != true;
              if (_isOffline != offline) {
                _isOffline = offline;
                notifyListeners();
              }
            },
            onError: (_) {
              _isOffline = true;
              notifyListeners();
            },
          );
    } catch (_) {
      /* Firebase may be unavailable during isolated unit tests. */
    }
  }

  Future<void> fetchFriends(String phoneNumber, {bool force = false}) async {
    if (!InputValidator.phone(phoneNumber)) return;
    if (_currentPhone == phoneNumber &&
        _subscription != null &&
        !force &&
        !_hasError) {
      return;
    }
    await _subscription?.cancel();
    if (_currentPhone != phoneNumber) {
      _friends.clear();
      _getPaise = 0;
      _givePaise = 0;
    }
    _currentPhone = phoneNumber;
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
    _initConnectivity();
    try {
      _subscription = FirebaseDatabase.instance
          .ref('Friends/$phoneNumber')
          .onValue
          .listen(
            (event) {
              final raw = event.snapshot.value;
              _friends.clear();
              if (raw is Map) {
                for (final entry in raw.entries) {
                  if (entry.value is Map) {
                    _friends.add(
                      LedgerTotals.normalize({
                        ...Map<String, dynamic>.from(entry.value as Map),
                        'friend_number': entry.key.toString(),
                      }),
                    );
                  }
                }
              }
              _getPaise = _friends.fold(
                0,
                (sum, f) => sum + (f['_getPaise'] as int),
              );
              _givePaise = _friends.fold(
                0,
                (sum, f) => sum + (f['_givePaise'] as int),
              );
              _isLoading = false;
              _hasError = false;
              _errorMessage = '';
              notifyListeners();
            },
            onError: (_) {
              _isLoading = false;
              _hasError = true;
              _errorMessage =
                  'Unable to sync friends ledger. Check your connection.';
              notifyListeners();
            },
          );
    } catch (_) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Unable to connect to the ledger.';
      notifyListeners();
    }
  }

  Future<AddFriendResult> addFriend({
    required String userPhone,
    required String friendName,
    required String friendNumber,
    String note = '',
    required String date,
  }) async {
    _lastError = null;
    final user = userPhone.trim(),
        number = friendNumber.trim(),
        name = friendName.trim();
    if (user.isEmpty || number.isEmpty || name.isEmpty) {
      _lastError = 'User phone, friend name, and phone number cannot be empty';
      return AddFriendResult.failed;
    }
    if (!InputValidator.phone(user) ||
        !InputValidator.phone(number) ||
        user == number ||
        name.length > 50 ||
        note.length > 200 ||
        !InputValidator.date(date)) {
      _lastError = 'Invalid friend details';
      return AddFriendResult.failed;
    }
    try {
      final ref = FirebaseDatabase.instance.ref('Friends/$user/$number');
      // Updating metadata cannot overwrite existing records even on timeout,
      // stale cache, or simultaneous friend creation.
      await ref.update({
        'friend_name': name,
        'friend_number': number,
        'note': note.trim(),
        'date': InputValidator.normalizedDate(date),
        ...InputValidator.dateFields(date),
      });
      return _friends.any((f) => f['friend_number'] == number)
          ? AddFriendResult.updated
          : AddFriendResult.added;
    } catch (_) {
      _lastError = 'Unable to save friend. Check your connection.';
      return AddFriendResult.failed;
    }
  }

  Future<bool> deleteFriend({
    required String userPhone,
    required String friendNumber,
  }) async {
    if (!InputValidator.phone(userPhone) ||
        !InputValidator.phone(friendNumber)) {
      return false;
    }
    try {
      _lastError = null;
      final snapshot = await FirebaseDatabase.instance
          .ref('Friends/$userPhone/$friendNumber')
          .get()
          .timeout(const Duration(seconds: 15));
      final data = snapshot.value;
      final records = data is Map ? data['Records'] : null;
      if (records is Map) {
        for (final entry in records.entries) {
          final record = entry.value;
          if (record is Map &&
              (record['split_id'] != null ||
                  SplitIntegrity.operationId(entry.key.toString()) !=
                      entry.key)) {
            _lastError =
                'Delete linked splits from the ledger before deleting this friend.';
            return false;
          }
        }
      }
      await FirebaseDatabase.instance
          .ref('Friends/$userPhone/$friendNumber')
          .remove();
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, Object?> _record(
    String key,
    String amount,
    String description,
    String paymentMode,
    String date,
    String categoryType,
  ) => {
    'key': key,
    'Amount': Money.decimal(Money.paise(amount)),
    'Description': description,
    'Payment_Mode': paymentMode,
    'Date': InputValidator.normalizedDate(date),
    ...InputValidator.dateFields(date),
    'Type': categoryType,
    'timestamp': ServerValue.timestamp,
  };
  Map<String, Object?> _expense(
    String key,
    String amount,
    String description,
    String paymentMode,
    String date,
    String category,
  ) => {
    'key': key,
    'Amount': Money.decimal(Money.paise(amount)),
    'Description': description,
    'Payment_Mode': paymentMode,
    'Date': InputValidator.normalizedDate(date),
    ...InputValidator.dateFields(date),
    'Category': category,
    'timestamp': ServerValue.timestamp,
  };
  bool _valid(
    String amount,
    String description,
    String mode,
    String date, {
    String? type,
    String? category,
  }) => InputValidator.transaction(
    amount: amount,
    description: description,
    mode: mode,
    date: date,
    type: type,
    category: category,
  );

  Future<bool> addFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String amount,
    required String description,
    required String paymentMode,
    required String date,
    required String categoryType,
    String? intentId,
  }) async {
    _lastError = null;
    if (!InputValidator.phone(userPhone) ||
        !InputValidator.phone(friendNumber) ||
        userPhone == friendNumber ||
        !_valid(amount, description, paymentMode, date, type: categoryType)) {
      _lastError = 'Invalid friend transaction details, amount, or date';
      return false;
    }
    final success = await RetrySafeWriter.instance.write(
      userPhone,
      'friend-record',
      [
        friendNumber,
        Money.decimal(Money.paise(amount)),
        description,
        paymentMode,
        InputValidator.normalizedDate(date),
        categoryType,
      ],
      (id) => {
        'Friends/$userPhone/$friendNumber/Records/$id': _record(
          id,
          amount,
          description,
          paymentMode,
          date,
          categoryType,
        ),
      },
      intentId: intentId,
    );
    if (!success) {
      _lastError = RetrySafeWriter.instance.failureMessage;
    }
    return success;
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
    final success = await atomicMultiFriendSplit(
      userPhone: userPhone,
      friendNumbers: friendNumbers,
      amountPerFriend: amountPerFriend,
      description: description,
      paymentMode: paymentMode,
      date: date,
      categoryType: categoryType,
    );
    return success ? friendNumbers.length : 0;
  }

  Future<bool> deleteFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String recordKey,
    required bool isGive,
    required num amount,
  }) async {
    if (!InputValidator.phone(userPhone) ||
        !InputValidator.phone(friendNumber) ||
        !InputValidator.key(recordKey)) {
      return false;
    }
    try {
      final splitPaths = await SplitIntegrity.load(userPhone, recordKey);
      if (splitPaths.isNotEmpty) {
        await FirebaseDatabase.instance.ref().update({
          for (final path in splitPaths) path: null,
        });
        return true;
      }
      await FirebaseDatabase.instance
          .ref('Friends/$userPhone/$friendNumber/Records/$recordKey')
          .remove();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String recordKey,
    required String amount,
    required String description,
  }) async {
    if (!InputValidator.phone(userPhone) ||
        !InputValidator.phone(friendNumber) ||
        !InputValidator.key(recordKey) ||
        !Money.positive(amount) ||
        !InputValidator.description(description)) {
      return false;
    }
    try {
      final ref = FirebaseDatabase.instance.ref(
        'Friends/$userPhone/$friendNumber/Records/$recordKey',
      );
      final record = (await ref.get().timeout(
        const Duration(seconds: 15),
      )).value;
      if (record is! Map) return false;
      final splitPaths = await SplitIntegrity.load(
        userPhone,
        recordKey,
        splitId: record['split_id']?.toString(),
      );
      if (splitPaths.isNotEmpty &&
          Money.paise(record['Amount']) != Money.paise(amount)) {
        _lastError =
            'Split amounts cannot be changed independently. Delete the split and record the corrected bill.';
        return false;
      }
      await FirebaseDatabase.instance
          .ref('Friends/$userPhone/$friendNumber/Records/$recordKey')
          .update({
            'Amount': Money.decimal(Money.paise(amount)),
            'Description': description,
          });
      return true;
    } catch (_) {
      return false;
    }
  }

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
    String? intentId,
  }) async {
    _lastError = null;
    if (Money.paise(myShareAmount) + Money.paise(friendShareAmount) !=
        Money.paise(totalAmount)) {
      _lastError = 'Split shares must add up to total amount';
      return false;
    }
    return atomicFullBillSplit(
      userPhone: userPhone,
      myShareAmount: myShareAmount,
      myDescription: '$description (Your share of ₹$totalAmount)',
      totalAmount: totalAmount,
      paymentMode: paymentMode,
      category: category,
      date: date,
      friendNumbers: [friendNumber],
      amountPerFriend: friendShareAmount,
      friendDescription: 'Split: $description (Total ₹$totalAmount)',
      categoryType: 'Give Money To Friend',
      intentId: intentId,
    );
  }

  Future<bool> atomicMultiFriendSplit({
    required String userPhone,
    required List<String> friendNumbers,
    required String amountPerFriend,
    required String description,
    required String paymentMode,
    required String date,
    required String categoryType,
  }) async {
    _lastError = null;
    if (!InputValidator.phone(userPhone) ||
        !_validFriends(userPhone, friendNumbers) ||
        !_valid(
          amountPerFriend,
          description,
          paymentMode,
          date,
          type: categoryType,
        )) {
      _lastError = 'Invalid friend split details';
      return false;
    }
    final numbers = [...friendNumbers]..sort();
    final success = await RetrySafeWriter.instance.write(
      userPhone,
      'multi-friend',
      [
        numbers,
        Money.decimal(Money.paise(amountPerFriend)),
        description,
        paymentMode,
        InputValidator.normalizedDate(date),
        categoryType,
      ],
      (id) => {
        for (var i = 0; i < numbers.length; i++)
          'Friends/$userPhone/${numbers[i]}/Records/${id}_$i': _record(
            '${id}_$i',
            amountPerFriend,
            description,
            paymentMode,
            date,
            categoryType,
          ),
      },
    );
    if (!success) {
      _lastError = RetrySafeWriter.instance.failureMessage;
    }
    return success;
  }

  bool _validFriends(String user, List<String> numbers) =>
      numbers.isNotEmpty &&
      numbers.length <= 100 &&
      numbers.toSet().length == numbers.length &&
      numbers.every((n) => InputValidator.phone(n) && n != user);

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
    String? intentId,
  }) async {
    _lastError = null;
    if (!InputValidator.phone(userPhone)) {
      _lastError = 'Invalid user phone number';
      return false;
    }
    if (!_validFriends(userPhone, friendNumbers)) {
      _lastError = 'Invalid friends selected for split';
      return false;
    }
    if (!Money.positive(totalAmount)) {
      _lastError = 'Please enter a valid total amount';
      return false;
    }
    if (!_valid(
          myShareAmount,
          myDescription,
          paymentMode,
          date,
          category: category,
        ) ||
        !_valid(
          amountPerFriend,
          friendDescription,
          paymentMode,
          date,
          type: categoryType,
        )) {
      _lastError = 'Invalid transaction details, date, or category';
      return false;
    }
    final total = Money.paise(totalAmount),
        mine = Money.paise(myShareAmount),
        friend = Money.paise(amountPerFriend);
    // This API intentionally supports equal friend shares with the remainder
    // assigned to the current user; no value is created or lost.
    if (categoryType == 'Give Money To Friend'
        ? mine + friend * friendNumbers.length != total
        : (friendNumbers.length != 1 || mine + friend != total || mine > total)) {
      _lastError = 'Split shares do not balance with total bill';
      return false;
    }
    final numbers = [...friendNumbers]..sort();
    final success = await RetrySafeWriter.instance.write(
      userPhone,
      'full-split',
      [
        numbers,
        Money.decimal(mine),
        myDescription,
        Money.decimal(total),
        paymentMode,
        category,
        InputValidator.normalizedDate(date),
        Money.decimal(friend),
        friendDescription,
        categoryType,
      ],
      (id) => {
        'Expenses/$userPhone/$id': {
          ..._expense(
            id,
            myShareAmount,
            myDescription,
            categoryType == 'Take Money From Friend' ? 'Owed' : paymentMode,
            date,
            category,
          ),
          'split_id': id,
        },
        for (var i = 0; i < numbers.length; i++)
          'Friends/$userPhone/${numbers[i]}/Records/${id}_$i': {
            ..._record(
              '${id}_$i',
              amountPerFriend,
              friendDescription,
              paymentMode,
              date,
              categoryType,
            ),
            'split_id': id,
          },
      },
      intentId: intentId,
    );
    if (!success) {
      _lastError = RetrySafeWriter.instance.failureMessage;
    }
    return success;
  }

  Future<bool> batchSaveMultiSplit({
    required String userPhone,
    required String tripTitle,
    required String formattedDate,
    required String paymentMode,
    required List<GroupExpense> expenses,
    required List<PersonSettlement> settlements,
    String? intentId,
  }) async {
    _lastError = null;
    if (!InputValidator.phone(userPhone) ||
        expenses.isEmpty ||
        expenses.length > 100 ||
        !InputValidator.description(tripTitle) ||
        !InputValidator.date(formattedDate) ||
        !InputValidator.mode(paymentMode)) {
      _lastError = 'Invalid trip details';
      return false;
    }
    try {
      final people = <String, SplitParticipant>{};
      for (final expense in expenses) {
        expense.validate();
        if (!InputValidator.date(expense.date.toIso8601String()) ||
            !InputValidator.categories.contains(expense.category)) {
          throw ArgumentError('Invalid expense');
        }
        people[expense.payer.phone] = expense.payer;
        for (final participant in expense.participants) {
          people[participant.phone] = participant;
        }
      }
      final me = people.values.where((p) => p.isMe).toList();
      if (me.length != 1 ||
          (me.single.phone != 'me' && me.single.phone != userPhone) ||
          people.values.any(
            (p) =>
                !p.isMe &&
                (!InputValidator.phone(p.phone) || p.phone == userPhone),
          )) {
        throw ArgumentError('Invalid participants');
      }
      // Never trust caller-supplied settlement amounts.
      final calculated = SplitHelper.calculatePersonSettlements(
        expenses: expenses,
        allParticipants: people.values.toList(),
      );
      final mine = calculated.singleWhere((s) => s.person.isMe);
      final payload = [
        tripTitle,
        paymentMode,
        InputValidator.normalizedDate(formattedDate),
        for (final e in expenses)
          [
            e.title,
            e.amount,
            e.category,
            InputValidator.normalizedDate(e.date.toIso8601String()),
            e.payer.phone,
            e.participants.map((p) => p.phone).toList(),
            e.customShares,
          ],
      ];
      final success = await RetrySafeWriter.instance.write(
        userPhone,
        'group-trip',
        payload,
        (id) {
          final updates = <String, Object?>{};
          for (var i = 0; i < expenses.length; i++) {
            final e = expenses[i], share = e.shareFor(me.single);
            if (Money.paise(share) > 0) {
              final key = '${id}_expense_$i';
              final description =
                  '$tripTitle: ${e.title} (Paid by ${e.payer.isMe ? 'You' : e.payer.name})';
              if (!InputValidator.description(description)) {
                throw ArgumentError('Description too long');
              }
              updates['Expenses/$userPhone/$key'] = {
                ..._expense(
                  key,
                  Money.decimal(Money.paise(share)),
                  description,
                  e.payer.isMe ? paymentMode : 'Owed',
                  '${e.date.day}/${e.date.month}/${e.date.year}',
                  e.category,
                ),
                'split_id': id,
              };
            }
          }
          final lines = [...mine.giveLines, ...mine.getLines];
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i], key = '${id}_debt_$i';
            updates['Friends/$userPhone/${line.otherPerson.phone}/Records/$key'] =
                {
                  ..._record(
                    key,
                    Money.decimal(Money.paise(line.amount)),
                    tripTitle,
                    paymentMode,
                    formattedDate,
                    line.isGive
                        ? 'Take Money From Friend'
                        : 'Give Money To Friend',
                  ),
                  'split_id': id,
                };
          }
          return updates;
        },
        intentId: intentId,
      );
      if (!success) _lastError = RetrySafeWriter.instance.failureMessage;
      return success;
    } catch (_) {
      _lastError = 'Invalid split or trip details';
      return false;
    }
  }

  void clearFriends() {
    _subscription?.cancel();
    _subscription = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _currentPhone = '';
    _friends.clear();
    _getPaise = 0;
    _givePaise = 0;
    _isOffline = false;
    _isLoading = false;
    _hasError = false;
    _errorMessage = '';
    _lastError = null;
    notifyListeners();
  }

  @visibleForTesting
  void setFriendsForTesting(
    List<Map<String, dynamic>> friends, {
    num totalGet = 0,
    num totalGive = 0,
  }) {
    _friends.clear();
    _friends.addAll(friends);
    _getPaise = Money.paise(totalGet);
    _givePaise = Money.paise(totalGive);
    _isLoading = false;
    _hasError = false;
    notifyListeners();
  }

  @visibleForTesting
  void setIsOfflineForTesting(bool value) {
    _isOffline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
