import 'package:fin_track/utils/money.dart';
import 'package:fin_track/services/retry_safe_writer.dart';
import 'package:fin_track/friends_pages/split_bill_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddSpent extends StatefulWidget {
  const AddSpent({super.key});

  @override
  State<AddSpent> createState() => _AddSpentState();
}

class _AddSpentState extends State<AddSpent> {
  bool isLoading = false;
  String _saveIntent = RetrySafeWriter.newIntent();
  final String? _draftOwnerUid = SessionManager.authenticatedUid;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  final List<String> paymentModes = const [
    "Spent Online",
    "Spent Cash",
    "Add CASH",
    "Add Online",
  ];

  final List<String> categories = const [
    "Food",
    "Shopping",
    "Transport",
    "Education",
    "HealthCare",
    "Entertainment",
    "Add Money",
    "Other",
  ];

  late String selectedMode;
  late String selectedCategory;

  // 👥 1-Tap Split with Friend State
  bool isSplitWithFriend = false;
  String? selectedFriendNumber;
  String? selectedFriendName;

  void _onAmountChanged() {
    _saveDraft();
    if (mounted) {
      setState(() {});
    }
  }

  void _addToAmount(double delta) {
    final current =
        (Money.tryPaise(amountController.text.replaceAll(',', '').trim()) ==
                null
            ? null
            : Money.rupees(amountController.text.replaceAll(',', '').trim())) ??
        0.0;
    final newVal = current + delta;
    final str = newVal.truncateToDouble() == newVal
        ? newVal.toInt().toString()
        : newVal.toStringAsFixed(2);
    amountController.text = str;
    amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: str.length),
    );
  }

  void _clearAmount() {
    amountController.clear();
  }

  static const _draftStorage = FlutterSecureStorage();
  Timer? _draftTimer;
  Future<void> _draftWrite = Future.value();
  String get _draftKey => 'expense_draft_${SessionManager.authenticatedPhone}';

  String _draftValue() => jsonEncode({
    'owner_uid': _draftOwnerUid,
    'amount': amountController.text,
    'description': descriptionController.text,
    'intent': _saveIntent,
    'mode': selectedMode,
    'category': selectedCategory,
    'date': selectedDate.toIso8601String(),
    'split': isSplitWithFriend,
    'friend': selectedFriendNumber,
    'friendName': selectedFriendName,
  });

  void _saveDraft() {
    _draftTimer?.cancel();
    if (SessionManager.authenticatedPhone == null ||
        SessionManager.authenticatedUid != _draftOwnerUid) {
      return;
    }
    final key = _draftKey;
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      if (SessionManager.authenticatedUid != _draftOwnerUid) return;
      final value = _draftValue();
      _draftWrite = _draftWrite
          .then((_) => _draftStorage.write(key: key, value: value))
          .catchError((_) {});
    });
  }

  Future<void> _restoreDraft() async {
    if (SessionManager.authenticatedPhone == null) return;
    try {
      final encoded = await _draftStorage.read(key: _draftKey);
      if (encoded == null || !mounted) return;
      final draft = jsonDecode(encoded) as Map<String, dynamic>;
      if (draft['owner_uid'] != _draftOwnerUid ||
          SessionManager.authenticatedUid != _draftOwnerUid) {
        return;
      }
      if (draft['intent'] is String &&
          await RetrySafeWriter.instance.isAcknowledged(
            SessionManager.authenticatedPhone!,
            draft['split'] == true ? 'full-split' : 'expense',
            draft['intent'] as String,
          )) {
        await _clearDraft();
        return; // Do not restore an acknowledged transaction as a new draft.
      }
      if (!mounted) return;
      _saveIntent = draft['intent']?.toString() ?? _saveIntent;
      if (paymentModes.contains(draft['mode'])) {
        selectedMode = draft['mode'] as String;
      }
      if (categories.contains(draft['category'])) {
        selectedCategory = draft['category'] as String;
      }
      selectedDate =
          DateTime.tryParse(draft['date']?.toString() ?? '') ?? selectedDate;
      isSplitWithFriend = draft['split'] == true;
      selectedFriendNumber = draft['friend']?.toString();
      selectedFriendName = draft['friendName']?.toString();
      if (amountController.text.isEmpty) {
        amountController.text = draft['amount']?.toString() ?? '';
      }
      if (descriptionController.text.isEmpty) {
        descriptionController.text = draft['description']?.toString() ?? '';
      }
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    try {
      await _draftWrite.timeout(const Duration(seconds: 3));
      await _draftStorage
          .delete(key: _draftKey)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // The server already acknowledged the save. Do not show false failure;
      // the retained intent makes restoring this stale draft non-duplicating.
    }
  }

  @override
  void initState() {
    super.initState();
    selectedMode = paymentModes.first;
    selectedCategory = categories.first;

    amountController.addListener(_onAmountChanged);
    descriptionController.addListener(_saveDraft);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriends();
      _restoreDraft();
    });
  }

  Future<void> _loadFriends() async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (phone.isNotEmpty && mounted) {
      context.read<FriendProvider>().fetchFriends(phone);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    amountController.removeListener(_onAmountChanged);
    descriptionController.removeListener(_saveDraft);
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(now) ? now : selectedDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> getAllDetails() async {
    if (isLoading) return;
    String rawAmount = amountController.text.trim();
    String description = descriptionController.text.trim();

    if (rawAmount.isEmpty || description.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill in all fields");
      return;
    }

    final totalAmount =
        (Money.tryPaise(rawAmount.replaceAll(',', '').trim()) == null
        ? null
        : Money.rupees(rawAmount.replaceAll(',', '').trim()));
    if (totalAmount == null || totalAmount <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid amount");
      return;
    }

    final isSpending = selectedMode.startsWith("Spent");
    final friends = context.read<FriendProvider>().friends;
    final effectiveFriendNumber =
        friends.any((f) => f["friend_number"] == selectedFriendNumber)
            ? selectedFriendNumber
            : (friends.isNotEmpty
                ? friends.first["friend_number"]?.toString()
                : null);
    if (isSplitWithFriend && isSpending && effectiveFriendNumber == null) {
      Fluttertoast.showToast(
        msg: "Please select a friend to split the bill with",
      );
      return;
    }
    selectedFriendNumber = effectiveFriendNumber;

    setState(() {
      isLoading = true;
    });

    try {
      if (SessionManager.authenticatedUid != _draftOwnerUid) {
        Fluttertoast.showToast(
          msg: 'Account changed. Reopen this form before saving.',
        );
        return;
      }
      _draftTimer?.cancel();
      await _draftWrite.timeout(const Duration(seconds: 3));
      await _draftStorage
          .write(key: _draftKey, value: _draftValue())
          .timeout(const Duration(seconds: 3));
      final phone = await SessionManager.getPhoneNumber() ?? "";
      if (phone.isEmpty) {
        Fluttertoast.showToast(msg: "User session not found");
        return;
      }

      String formattedDate = DateFormat('d/M/yyyy').format(selectedDate);
      if (!mounted) return;

      final expenseProvider = context.read<ExpenseProvider>();
      final friendProvider = context.read<FriendProvider>();

      if (isSplitWithFriend && isSpending && selectedFriendNumber != null) {
        final friendShare = (Money.paise(totalAmount) ~/ 2) / 100;
        final myShare =
            (Money.paise(totalAmount) - Money.paise(friendShare)) / 100;

        final myShareStr = myShare.truncateToDouble() == myShare
            ? myShare.toInt().toString()
            : myShare.toStringAsFixed(2);
        final friendShareStr = friendShare.truncateToDouble() == friendShare
            ? friendShare.toInt().toString()
            : friendShare.toStringAsFixed(2);
        final totalAmountStr = totalAmount.truncateToDouble() == totalAmount
            ? totalAmount.toInt().toString()
            : totalAmount.toStringAsFixed(2);

        // Single atomic multi-path update for Passbook + Friend Ledger
        final splitSuccess = await friendProvider.atomicSplitBill(
          intentId: _saveIntent,
          userPhone: phone,
          friendNumber: selectedFriendNumber!,
          myShareAmount: myShareStr,
          friendShareAmount: friendShareStr,
          totalAmount: totalAmountStr,
          description: description,
          date: formattedDate,
          category: selectedCategory,
          paymentMode: selectedMode,
        );

        if (splitSuccess) {
          await _clearDraft();
          // The existing realtime subscription refreshes the expense ledger.
          Fluttertoast.showToast(
            msg:
                "Saved! ₹$myShareStr in Passbook & ₹$friendShareStr added to $selectedFriendName's ledger",
          );
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(
            msg: friendProvider.lastError ??
                RetrySafeWriter.instance.failureMessage,
          );
        }
      } else {
        final rawAmountFormatted = totalAmount.truncateToDouble() == totalAmount
            ? totalAmount.toInt().toString()
            : totalAmount.toStringAsFixed(2);

        // Standard single transaction
        final success = await expenseProvider.addExpense(
          intentId: _saveIntent,
          phoneNumber: phone,
          amount: rawAmountFormatted,
          description: description,
          paymentMode: selectedMode,
          date: formattedDate,
          category: selectedCategory,
        );

        if (success) {
          await _clearDraft();
          Fluttertoast.showToast(msg: "Transaction added successfully");
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(
            msg: expenseProvider.lastError ??
                RetrySafeWriter.instance.failureMessage,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save transaction");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF8BC24A);
    final friendProvider = context.watch<FriendProvider>();
    final friends = friendProvider.friends;
    final isSpending = selectedMode.startsWith("Spent");
    final currentAmount =
        (Money.tryPaise(amountController.text.replaceAll(',', '').trim()) ==
                null
            ? null
            : Money.rupees(amountController.text.replaceAll(',', '').trim())) ??
        0.0;
    final friendSharePreview = (Money.paise(currentAmount) ~/ 2) / 100;
    final mySharePreview =
        (Money.paise(currentAmount) - Money.paise(friendSharePreview)) / 100;

    final mySharePreviewStr =
        mySharePreview.truncateToDouble() == mySharePreview
        ? mySharePreview.toInt().toString()
        : mySharePreview.toStringAsFixed(2);
    final friendSharePreviewStr =
        friendSharePreview.truncateToDouble() == friendSharePreview
        ? friendSharePreview.toInt().toString()
        : friendSharePreview.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Add Transaction",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Amount Card with Quick Add Chips
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "TRANSACTION AMOUNT",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (amountController.text.isNotEmpty)
                              GestureDetector(
                                onTap: _clearAmount,
                                child: Text(
                                  "Clear",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "₹",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'),
                                  ),
                                ],
                                maxLength: 10,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "0.00",
                                  hintStyle: TextStyle(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  border: InputBorder.none,
                                  counterText: "",
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Quick Add Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _quickAddChip("+100", () => _addToAmount(100)),
                              _quickAddChip("+500", () => _addToAmount(500)),
                              _quickAddChip("+1,000", () => _addToAmount(1000)),
                              _quickAddChip("+2,000", () => _addToAmount(2000)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Category Selector Section
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Select Category",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CategoryTheme.getBgColor(
                                  selectedCategory,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CategoryTheme.getIcon(selectedCategory),
                                    size: 14,
                                    color: CategoryTheme.getColor(
                                      selectedCategory,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedCategory,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: CategoryTheme.getColor(
                                        selectedCategory,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Category Pills Grid/Wrap
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((cat) {
                            final isSelected = selectedCategory == cat;
                            final catColor = CategoryTheme.getColor(cat);
                            final catBg = CategoryTheme.getBgColor(cat);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCategory = cat;
                                  // Auto adjust payment mode if category is Add Money
                                  if (cat == "Add Money" &&
                                      selectedMode.startsWith("Spent")) {
                                    selectedMode = "Add CASH";
                                  } else if (cat != "Add Money" &&
                                      selectedMode.startsWith("Add")) {
                                    selectedMode = "Spent Online";
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? catBg
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? catColor
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CategoryTheme.getIcon(cat),
                                      size: 16,
                                      color: isSelected
                                          ? catColor
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? catColor
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Payment Mode & Type Selector
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Payment Mode",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _paymentModePill(
                              "Spent Online",
                              "Online Spent",
                              Icons.credit_card_rounded,
                              primary,
                            ),
                            const SizedBox(width: 8),
                            _paymentModePill(
                              "Spent Cash",
                              "Cash Spent",
                              Icons.payments_rounded,
                              const Color(0xFFFFA000),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _paymentModePill(
                              "Add Online",
                              "Add Online",
                              Icons.account_balance_rounded,
                              const Color(0xFF2196F3),
                            ),
                            const SizedBox(width: 8),
                            _paymentModePill(
                              "Add CASH",
                              "Add Cash",
                              Icons.savings_rounded,
                              const Color(0xFF43A047),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Date & Description Note
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Date picker row
                        InkWell(
                          onTap: pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat(
                                    'dd MMMM yyyy',
                                  ).format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  "Change",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Note TextField
                        TextField(
                          controller: descriptionController,
                          maxLength: 150,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText:
                                "Add note / description (e.g. Grocery, Lunch)",
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                            prefixIcon: const Icon(
                              Icons.edit_note_rounded,
                              color: primary,
                              size: 22,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            counterText: "",
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: primary,
                                width: 1.8,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 5. 👥 1-Tap Bill Split Section (Available for Expense transactions)
                  if (isSpending) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isSplitWithFriend
                            ? const Color(0xFFF7FEE7)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSplitWithFriend
                              ? primary
                              : const Color(0xFFE2E8F0),
                          width: isSplitWithFriend ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSplitWithFriend
                                            ? primary.withValues(alpha: 0.15)
                                            : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.group_rounded,
                                        size: 20,
                                        color: isSplitWithFriend
                                            ? primary
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Split Bill with Friend",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            "Split 50/50 instantly",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch.adaptive(
                                value: isSplitWithFriend,
                                activeTrackColor: primary,
                                activeThumbColor: Colors.white,
                                onChanged: (val) {
                                  setState(() {
                                    isSplitWithFriend = val;
                                    if (val &&
                                        friends.isNotEmpty &&
                                        selectedFriendNumber == null) {
                                      selectedFriendNumber =
                                          friends.first["friend_number"];
                                      selectedFriendName =
                                          friends.first["friend_name"];
                                    }
                                  });
                                },
                              ),
                            ],
                          ),

                          if (isSplitWithFriend) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),

                            if (friends.isEmpty)
                              const Text(
                                "No friends found. Add friends in the Friends tab to split bills.",
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12.5,
                                ),
                              )
                            else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: friends.any((f) =>
                                            f["friend_number"] ==
                                            selectedFriendNumber)
                                        ? selectedFriendNumber
                                        : (friends.isNotEmpty
                                            ? friends.first["friend_number"]
                                                ?.toString()
                                            : null),
                                    icon: const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: primary,
                                    ),
                                    items: friends.map((f) {
                                      final name =
                                          (f["friend_name"] ?? "Friend")
                                              .toString();
                                      final number = (f["friend_number"] ?? "")
                                          .toString();
                                      return DropdownMenuItem<String>(
                                        value: number,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: primary
                                                  .withValues(alpha: 0.2),
                                              child: Text(
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : 'F',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "$name ($number)",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final matched = friends.firstWhere(
                                          (f) => f["friend_number"] == val,
                                          orElse: () => {
                                            "friend_name": "Friend",
                                          },
                                        );
                                        setState(() {
                                          selectedFriendNumber = val;
                                          selectedFriendName =
                                              matched["friend_name"];
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),

                              if (currentAmount > 0) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Your Expense: ₹$mySharePreviewStr",
                                            style: const TextStyle(
                                              color: Color(0xFF2E7D32),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            "Friend Owes: ₹$friendSharePreviewStr",
                                            style: const TextStyle(
                                              color: Color(0xFFC62828),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 8),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SplitBillPage(),
                                      ),
                                    );
                                    if (res == true && context.mounted) {
                                      _clearDraft();
                                      Navigator.pop(context, true);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.group_work_rounded,
                                    size: 16,
                                    color: primary,
                                  ),
                                  label: const Text(
                                    "Split with 2+ friends? Open Group Splitter ➔",
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 6. Save Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : getAllDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isSplitWithFriend
                            ? "Save & Split Bill"
                            : "Save Transaction",
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickAddChip(String label, VoidCallback onTap) {
    const Color primary = Color(0xFF8BC24A);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF558B2F),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentModePill(
    String modeKey,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedMode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedMode = modeKey;
            // If selecting income, sync category if necessary
            if (modeKey.startsWith("Add") && selectedCategory != "Add Money") {
              selectedCategory = "Add Money";
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? color : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
