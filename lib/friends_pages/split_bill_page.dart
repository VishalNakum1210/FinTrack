import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/split_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SplitBillPage extends StatefulWidget {
  const SplitBillPage({super.key});

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  // ── Mode Tab: 0 = Single Bill, 1 = Group Trip (Multi-Split) ──
  int _activeTab = 0;

  // ── Single Bill State ──
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String selectedCategory = "Food";
  String selectedMode = "Spent Online";
  final Set<String> selectedFriendNumbers = {};
  String singleBillPayerPhone = "me"; // "me" or friend phone number

  // ── Group Trip / Multi-Split State ──
  final TextEditingController tripTitleController =
      TextEditingController(text: "Trip Expenses");
  final Set<String> tripSelectedFriendNumbers = {};
  final List<GroupExpense> tripExpenses = [];

  String _currentUserPhone = "";
  String _currentUserName = "You";
  bool isLoading = false;

  final List<String> categories = const [
    "Food",
    "Shopping",
    "Transport",
    "Education",
    "HealthCare",
    "Entertainment",
    "Other",
  ];

  final List<String> paymentModes = const [
    "Spent Online",
    "Spent Cash",
  ];

  @override
  void initState() {
    super.initState();
    amountController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  void _addToAmount(double delta) {
    final current =
        double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final newVal = current + delta;
    final str = newVal.truncateToDouble() == newVal
        ? newVal.toInt().toString()
        : newVal.toStringAsFixed(2);
    amountController.text = str;
    amountController.selection =
        TextSelection.fromPosition(TextPosition(offset: str.length));
  }

  void _clearAmount() {
    amountController.clear();
  }

  void _onSingleBillPayerSelected(String newPayerPhone) {
    if (singleBillPayerPhone == newPayerPhone) return;
    setState(() {
      final oldPayer = singleBillPayerPhone;
      if (oldPayer != "me") {
        selectedFriendNumbers.remove(oldPayer);
      }
      if (newPayerPhone != "me") {
        selectedFriendNumbers.add(newPayerPhone);
      }
      singleBillPayerPhone = newPayerPhone;
    });
  }

  Future<void> _loadInitialData() async {
    String phone = await SessionManager.getPhoneNumber() ?? "";
    if (phone.isEmpty) {
      final authEmail = FirebaseAuth.instance.currentUser?.email;
      if (authEmail != null && authEmail.endsWith('@fintrack.app')) {
        phone = authEmail.split('@').first;
      }
    }
    phone = phone.trim();
    final username = await SessionManager.getUsername() ?? "You";
    if (mounted) {
      setState(() {
        _currentUserPhone = phone;
        _currentUserName = username.isNotEmpty ? username : "You";
      });
      if (phone.isNotEmpty) {
        context.read<FriendProvider>().fetchFriends(phone);
      }
    }
  }

  @override
  void dispose() {
    amountController.removeListener(_onAmountChanged);
    amountController.dispose();
    descriptionController.dispose();
    tripTitleController.dispose();
    super.dispose();
  }

  Future<void> pickDate(
      {DateTime? initial, required Function(DateTime) onPicked}) async {
    final now = DateTime.now();
    final init = initial ?? selectedDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: init.isAfter(now) ? now : init,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked != null) {
      onPicked(picked);
    }
  }

  // Helper: Get SplitParticipant for Current User
  SplitParticipant get _meParticipant => SplitParticipant(
        phone: _currentUserPhone.isNotEmpty ? _currentUserPhone : "0000000000",
        name: _currentUserName.isNotEmpty ? _currentUserName : "You",
        isMe: true,
      );

  // Helper: Build Participants List for Group Trip
  List<SplitParticipant> _getTripParticipants(
      List<Map<String, dynamic>> allFriends) {
    final List<SplitParticipant> participants = [_meParticipant];
    for (final f in allFriends) {
      final phone = (f["friend_number"] ?? f["phone"] ?? "").toString();
      if (tripSelectedFriendNumbers.contains(phone)) {
        final name = (f["friend_name"] ?? f["name"] ?? phone).toString();
        participants.add(SplitParticipant(phone: phone, name: name));
      }
    }
    return participants;
  }

  // ────────────────────────────────────────────────────────────
  // SINGLE BILL SPLIT HANDLER
  // ────────────────────────────────────────────────────────────
  Future<void> handleSplitBill() async {
    final rawAmount = amountController.text.trim();
    final description = descriptionController.text.trim();

    if (rawAmount.isEmpty || description.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill in amount and description");
      return;
    }

    final totalAmount = double.tryParse(rawAmount.replaceAll(',', '').trim());
    if (totalAmount == null || totalAmount <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid amount");
      return;
    }

    if (selectedFriendNumbers.isEmpty) {
      Fluttertoast.showToast(msg: "Please select at least 1 friend to split with");
      return;
    }

    final totalPeople = selectedFriendNumbers.length + 1;
    final sharePerPerson = ((totalAmount / totalPeople) * 100).round() / 100;
    final myShare =
        ((totalAmount - (sharePerPerson * selectedFriendNumbers.length)) * 100)
                .round() /
            100;
    final formattedDate = DateFormat('d/M/yyyy').format(selectedDate);

    final myShareStr = myShare.truncateToDouble() == myShare
        ? myShare.toInt().toString()
        : myShare.toStringAsFixed(2);
    final sharePerPersonStr = sharePerPerson.truncateToDouble() == sharePerPerson
        ? sharePerPerson.toInt().toString()
        : sharePerPerson.toStringAsFixed(2);
    final totalAmountStr = totalAmount.truncateToDouble() == totalAmount
        ? totalAmount.toInt().toString()
        : totalAmount.toStringAsFixed(2);

    final isPayerMe = singleBillPayerPhone == "me";

    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return PopScope(
              canPop: !isSaving,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Confirm Bill Split",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text("Total Bill: ₹$totalAmountStr",
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      isPayerMe
                          ? "Payer: You (Friends will owe you their share)"
                          : "Payer: Friend (You will owe your share)",
                      style: TextStyle(
                        fontSize: 14,
                        color: isPayerMe
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("Your Share: ₹$myShareStr (to Passbook)",
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text("Each Friend's Share: ₹$sharePerPersonStr",
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(modalCtx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            child: const Text("Cancel",
                                style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setModalState(() {
                                      isSaving = true;
                                    });

                                    try {
                                      String userPhone =
                                          await SessionManager.getPhoneNumber() ??
                                              "";
                                      if (userPhone.isEmpty) {
                                        final authEmail = FirebaseAuth
                                            .instance.currentUser?.email;
                                        if (authEmail != null &&
                                            authEmail.endsWith('@fintrack.app')) {
                                          userPhone =
                                              authEmail.split('@').first;
                                        }
                                      }
                                      userPhone = userPhone.trim();
                                      if (userPhone.isEmpty) {
                                        Fluttertoast.showToast(
                                            msg:
                                                "User session not found. Please log in again.");
                                        setModalState(() => isSaving = false);
                                        return;
                                      }

                                      if (!mounted) return;
                                      final friendProvider =
                                          context.read<FriendProvider>();

                                      if (isPayerMe) {
                                        final splitSuccess =
                                            await friendProvider
                                                .atomicFullBillSplit(
                                          userPhone: userPhone,
                                          myShareAmount: myShareStr,
                                          myDescription:
                                              "$description (Your 1/$totalPeople share of ₹$totalAmountStr)",
                                          totalAmount: totalAmountStr,
                                          paymentMode: selectedMode,
                                          category: selectedCategory,
                                          date: formattedDate,
                                          friendNumbers:
                                              selectedFriendNumbers.toList(),
                                          amountPerFriend: sharePerPersonStr,
                                          friendDescription:
                                              "Split: $description (Total ₹$totalAmountStr across $totalPeople people)",
                                          categoryType: "Give Money To Friend",
                                        );

                                        if (splitSuccess) {
                                          Fluttertoast.showToast(
                                            msg:
                                                "Split Complete! Added ₹$myShareStr to your passbook & ₹$sharePerPersonStr to friends' ledgers.",
                                          );
                                          if (modalCtx.mounted) {
                                            Navigator.pop(modalCtx);
                                          }
                                          if (mounted) {
                                            Navigator.pop(context, true);
                                          }
                                        } else {
                                          Fluttertoast.showToast(
                                              msg:
                                                  "Failed to record bill split. Please retry.");
                                          if (modalCtx.mounted) {
                                            setModalState(
                                                () => isSaving = false);
                                          }
                                        }
                                      } else {
                                        final splitSuccess =
                                            await friendProvider
                                                .atomicFullBillSplit(
                                          userPhone: userPhone,
                                          myShareAmount: myShareStr,
                                          myDescription:
                                              "$description (Your share paid by friend)",
                                          totalAmount: totalAmountStr,
                                          paymentMode: selectedMode,
                                          category: selectedCategory,
                                          date: formattedDate,
                                          friendNumbers: [
                                            singleBillPayerPhone
                                          ],
                                          amountPerFriend: myShareStr,
                                          friendDescription:
                                              "Split: $description (You owe friend your share of ₹$totalAmountStr)",
                                          categoryType: "Take Money From Friend",
                                        );

                                        if (splitSuccess) {
                                          Fluttertoast.showToast(
                                            msg:
                                                "Split Complete! Recorded ₹$myShareStr owed to friend in ledger.",
                                          );
                                          if (modalCtx.mounted) {
                                            Navigator.pop(modalCtx);
                                          }
                                          if (mounted) {
                                            Navigator.pop(context, true);
                                          }
                                        } else {
                                          Fluttertoast.showToast(
                                              msg:
                                                  "Failed to record bill split. Please retry.");
                                          if (modalCtx.mounted) {
                                            setModalState(
                                                () => isSaving = false);
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      Fluttertoast.showToast(
                                          msg: "Error splitting bill: $e");
                                      if (modalCtx.mounted) {
                                        setModalState(() => isSaving = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8BC24A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: isSaving
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Splitting...",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      "Confirm & Split",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // GROUP TRIP (MULTI-SPLIT) MODAL: ADD EXPENSE TO TRIP
  // ────────────────────────────────────────────────────────────
  void _openAddExpenseModal(List<SplitParticipant> participants) {
    if (participants.length < 2) {
      Fluttertoast.showToast(
          msg: "Please select at least 1 friend to include in the trip first");
      return;
    }

    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String expCategory = "Food";
    SplitParticipant expPayer = participants.first;
    final Set<String> expConsumerPhones =
        participants.map((p) => p.phone).toSet();
    DateTime expDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Add Expense to Trip",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: "Expense Title (e.g. Dinner, Train, Fuel)",
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "Total Amount",
                        prefixText: "₹ ",
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: expCategory,
                            decoration: InputDecoration(
                              labelText: "Category",
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Row(
                                  children: [
                                    Icon(CategoryTheme.getIcon(cat),
                                        size: 18,
                                        color: CategoryTheme.getColor(cat)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cat,
                                        style: const TextStyle(fontSize: 13.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => expCategory = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () {
                            pickDate(
                              initial: expDate,
                              onPicked: (picked) {
                                setModalState(() => expDate = picked);
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 16, color: Color(0xFF8BC24A)),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('dd MMM').format(expDate),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      "Who Paid the Bill?",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: participants.map((p) {
                        final isSelected = expPayer == p;
                        return ChoiceChip(
                          label: Text(p.isMe ? "You" : p.name),
                          selected: isSelected,
                          selectedColor:
                              const Color(0xFF8BC24A).withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF334155),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => expPayer = p);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      "Split Between Who?",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: participants.map((p) {
                        final isIncluded = expConsumerPhones.contains(p.phone);
                        return FilterChip(
                          label: Text(p.isMe ? "You" : p.name),
                          selected: isIncluded,
                          selectedColor:
                              const Color(0xFF8BC24A).withValues(alpha: 0.2),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                expConsumerPhones.add(p.phone);
                              } else {
                                if (expConsumerPhones.length > 1) {
                                  expConsumerPhones.remove(p.phone);
                                } else {
                                  Fluttertoast.showToast(
                                      msg: "At least 1 person must share this expense");
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),

                    ElevatedButton(
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final rawAmt = amountCtrl.text.trim();
                        final parsedAmt = double.tryParse(rawAmt);

                        if (title.isEmpty) {
                          Fluttertoast.showToast(
                              msg: "Please enter an expense title");
                          return;
                        }
                        if (parsedAmt == null || parsedAmt <= 0) {
                          Fluttertoast.showToast(
                              msg: "Please enter a valid amount");
                          return;
                        }

                        final consumers = participants
                            .where((p) => expConsumerPhones.contains(p.phone))
                            .toList();

                        final newExpense = GroupExpense(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          amount: parsedAmt,
                          category: expCategory,
                          date: expDate,
                          payer: expPayer,
                          participants: consumers,
                        );

                        setState(() {
                          tripExpenses.add(newExpense);
                        });

                        Navigator.pop(modalCtx);
                        Fluttertoast.showToast(msg: "Added '$title' to Trip!");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8BC24A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Add to Trip",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // GROUP TRIP SAVE HANDLER
  // ────────────────────────────────────────────────────────────
  Future<void> handleSaveGroupTrip(List<SplitParticipant> participants) async {
    if (tripExpenses.isEmpty) {
      Fluttertoast.showToast(msg: "Please add at least 1 expense to the trip");
      return;
    }

    final tripTitle = tripTitleController.text.trim();
    if (tripTitle.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter a trip title");
      return;
    }

    final settlements = SplitHelper.calculatePersonSettlements(
      expenses: tripExpenses,
      allParticipants: participants,
    );

    final totalTripAmount =
        tripExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final totalTripStr = totalTripAmount.toINR();
    final formattedDate = DateFormat('d/M/yyyy').format(DateTime.now());

    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return PopScope(
              canPop: !isSaving,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Confirm Trip Split: $tripTitle",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Total Trip Expenses: $totalTripStr (${tripExpenses.length} bills)",
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Participants: ${participants.length} people",
                      style: const TextStyle(
                          fontSize: 13.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Saving will atomically update your Passbook and all mutual balances in each friend's ledger.",
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(modalCtx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            child: const Text("Review",
                                style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setModalState(() {
                                      isSaving = true;
                                    });

                                    try {
                                      String userPhone =
                                          await SessionManager.getPhoneNumber() ??
                                              "";
                                      if (userPhone.isEmpty) {
                                        final authEmail = FirebaseAuth
                                            .instance.currentUser?.email;
                                        if (authEmail != null &&
                                            authEmail.endsWith('@fintrack.app')) {
                                          userPhone =
                                              authEmail.split('@').first;
                                        }
                                      }
                                      userPhone = userPhone.trim();
                                      if (userPhone.isEmpty) {
                                        Fluttertoast.showToast(
                                            msg:
                                                "User session not found. Please log in again.");
                                        setModalState(() => isSaving = false);
                                        return;
                                      }

                                      if (!mounted) return;
                                      final friendProvider =
                                          context.read<FriendProvider>();

                                      final success = await friendProvider
                                          .batchSaveMultiSplit(
                                        userPhone: userPhone,
                                        tripTitle: tripTitle,
                                        formattedDate: formattedDate,
                                        paymentMode: "Spent Online",
                                        expenses: tripExpenses,
                                        settlements: settlements,
                                      );

                                      if (success) {
                                        Fluttertoast.showToast(
                                          msg:
                                              "Trip Saved! Updated Passbook and Friend Ledgers successfully.",
                                        );
                                        if (modalCtx.mounted) {
                                          Navigator.pop(modalCtx);
                                        }
                                        if (mounted) {
                                          Navigator.pop(context, true);
                                        }
                                      } else {
                                        final err = friendProvider.lastError;
                                        Fluttertoast.showToast(
                                          msg: (err != null && err.isNotEmpty)
                                              ? "Failed to save: $err"
                                              : "Failed to save trip split. Please retry.",
                                        );
                                        if (modalCtx.mounted) {
                                          setModalState(() => isSaving = false);
                                        }
                                      }
                                    } catch (e) {
                                      Fluttertoast.showToast(
                                          msg: "Error saving trip: $e");
                                      if (modalCtx.mounted) {
                                        setModalState(() => isSaving = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8BC24A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Saving...",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    "Save to Ledgers",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // BUILD METHOD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF8BC24A);
    final friendProvider = context.watch<FriendProvider>();
    final friends = friendProvider.friends;

    final tripParticipants = _getTripParticipants(friends);
    final settlements = SplitHelper.calculatePersonSettlements(
      expenses: tripExpenses,
      allParticipants: tripParticipants,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          "Split Bill & Group Trips",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeTab = 0),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeTab == 0
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _activeTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "⚡ Single Bill",
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontWeight: _activeTab == 0
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: _activeTab == 0
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF64748B),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeTab = 1),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeTab == 1
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _activeTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "🏖️ Group Trip (Multi-Split)",
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontWeight: _activeTab == 1
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: _activeTab == 1
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF64748B),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_activeTab == 0) ...[
                    _buildSingleBillView(primary, friends),
                  ] else ...[
                    _buildGroupTripView(
                        primary, friends, tripParticipants, settlements),
                  ],

                  const SizedBox(height: 30),
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

  // ────────────────────────────────────────────────────────────
  // SINGLE BILL SPLIT WIDGETS
  // ────────────────────────────────────────────────────────────
  Widget _buildSingleBillView(
      Color primary, List<Map<String, dynamic>> friends) {
    final totalAmount =
        double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final totalPeople = selectedFriendNumbers.length + 1;
    final sharePerPerson = totalAmount > 0
        ? ((totalAmount / totalPeople) * 100).round() / 100
        : 0.0;
    final myShare = totalAmount > 0
        ? ((totalAmount - (sharePerPerson * selectedFriendNumbers.length)) * 100)
                .round() /
            100
        : 0.0;

    final myShareStr = myShare.truncateToDouble() == myShare
        ? myShare.toInt().toString()
        : myShare.toStringAsFixed(2);
    final sharePerPersonStr = sharePerPerson.truncateToDouble() == sharePerPerson
        ? sharePerPerson.toInt().toString()
        : sharePerPerson.toStringAsFixed(2);
    final totalAmountStr = totalAmount.truncateToDouble() == totalAmount
        ? totalAmount.toInt().toString()
        : totalAmount.toStringAsFixed(2);
    final totalCollect = sharePerPerson * selectedFriendNumbers.length;
    final totalCollectStr = totalCollect.truncateToDouble() == totalCollect
        ? totalCollect.toInt().toString()
        : totalCollect.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    "Total Bill Amount",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
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
                      color: Color(0xFF8BC24A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      maxLength: 10,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: "0.00",
                        hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
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
                "Bill Information",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLength: 150,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: "Enter bill title (e.g. Dinner, Movie, Uber)",
                  hintStyle:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  prefixIcon: const Icon(Icons.receipt_long_rounded,
                      color: Color(0xFF8BC24A), size: 22),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  counterText: "",
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color(0xFF8BC24A), width: 1.8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  pickDate(
                    initial: selectedDate,
                    onPicked: (picked) => setState(() => selectedDate = picked),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: Color(0xFF8BC24A), size: 20),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd MMMM yyyy').format(selectedDate),
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
                          color: Color(0xFF8BC24A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: "Category",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(CategoryTheme.getIcon(cat),
                                  size: 18,
                                  color: CategoryTheme.getColor(cat)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cat,
                                  style: const TextStyle(fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCategory = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedMode,
                      decoration: InputDecoration(
                        labelText: "Paid Via",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      items: paymentModes.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(
                            mode,
                            style: const TextStyle(fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedMode = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
                "Who Paid the Bill?",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: const Text("You (I Paid)"),
                      selected: singleBillPayerPhone == "me",
                      selectedColor:
                          const Color(0xFF8BC24A).withValues(alpha: 0.25),
                      onSelected: (val) {
                        if (val) _onSingleBillPayerSelected("me");
                      },
                    ),
                    const SizedBox(width: 8),
                    ...friends.map((f) {
                      final phone =
                          (f["friend_number"] ?? f["phone"] ?? "").toString();
                      final name =
                          (f["friend_name"] ?? f["name"] ?? phone).toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: singleBillPayerPhone == phone,
                          selectedColor: const Color(0xFF8BC24A)
                              .withValues(alpha: 0.25),
                          onSelected: (val) {
                            if (val) {
                              _onSingleBillPayerSelected(phone);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
                    "Split with Friends",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (friends.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (selectedFriendNumbers.length == friends.length) {
                            selectedFriendNumbers.clear();
                          } else {
                            selectedFriendNumbers.clear();
                            for (final f in friends) {
                              selectedFriendNumbers.add((f["friend_number"] ??
                                      f["phone"] ??
                                      "")
                                  .toString());
                            }
                          }
                        });
                      },
                      child: Text(
                        selectedFriendNumbers.length == friends.length
                            ? "Deselect All"
                            : "Select All",
                        style: const TextStyle(
                          color: Color(0xFF8BC24A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      "No friends added yet. Add friends from the Friends tab first.",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friends.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final f = friends[idx];
                    final phone =
                        (f["friend_number"] ?? f["phone"] ?? "").toString();
                    final name =
                        (f["friend_name"] ?? f["name"] ?? phone).toString();
                    final isChecked = selectedFriendNumbers.contains(phone);

                    return Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedFriendNumbers.add(phone);
                            } else {
                              selectedFriendNumbers.remove(phone);
                            }
                          });
                        },
                        title: Text(name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(phone,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
                        activeColor: const Color(0xFF8BC24A),
                        contentPadding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (totalAmount > 0 && selectedFriendNumbers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FEE7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: const Color(0xFF8BC24A).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Live Calculation",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      "$totalPeople People",
                      style: const TextStyle(
                        color: Color(0xFF33691E),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "₹$sharePerPersonStr / person",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  singleBillPayerPhone == "me"
                      ? "• Your share: ₹$myShareStr (to Passbook)\n• Friends will owe you: ₹$totalCollectStr"
                      : "• Your share: ₹$myShareStr (You will owe to payer)",
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed:
                (isLoading || totalAmount <= 0 || selectedFriendNumbers.isEmpty)
                    ? null
                    : handleSplitBill,
            icon: const Icon(Icons.call_split_rounded,
                color: Colors.white, size: 20),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                totalAmount > 0 && selectedFriendNumbers.isNotEmpty
                    ? "Confirm Split (₹$totalAmountStr)"
                    : "Select Friends & Enter Bill",
                maxLines: 1,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // GROUP TRIP & MULTI-SPLIT WIDGETS (USER'S RATED IDEA!)
  // ────────────────────────────────────────────────────────────
  Widget _buildGroupTripView(
    Color primary,
    List<Map<String, dynamic>> friends,
    List<SplitParticipant> participants,
    List<PersonSettlement> settlements,
  ) {
    final totalTripSpent =
        tripExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                "Trip / Event Information",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tripTitleController,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  labelText: "Trip Name",
                  hintText: "e.g. Goa Trip 2026, Weekend Outing",
                  prefixIcon: const Icon(Icons.beach_access_rounded,
                      color: Color(0xFF8BC24A)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
                    "Trip Members",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    "${participants.length} Members",
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: Color(0xFF2E7D32),
                      child: Text("Y",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    label: Text(_currentUserName),
                    backgroundColor:
                        const Color(0xFF8BC24A).withValues(alpha: 0.15),
                  ),
                  ...friends.map((f) {
                    final phone =
                        (f["friend_number"] ?? f["phone"] ?? "").toString();
                    final name =
                        (f["friend_name"] ?? f["name"] ?? phone).toString();
                    final isChecked =
                        tripSelectedFriendNumbers.contains(phone);

                    return FilterChip(
                      label: Text(name),
                      selected: isChecked,
                      selectedColor:
                          const Color(0xFF8BC24A).withValues(alpha: 0.25),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            tripSelectedFriendNumbers.add(phone);
                          } else {
                            tripSelectedFriendNumbers.remove(phone);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Trip Expenses",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${tripExpenses.length} Bills • Total: ${totalTripSpent.toINR()}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openAddExpenseModal(participants),
                    icon: const Icon(Icons.add, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("Add Bill"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8BC24A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (tripExpenses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          "No expenses added yet",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Tap '+ Add Bill' above to add dinner, tickets, hotel, etc.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tripExpenses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final exp = tripExpenses[idx];
                    final payerName =
                        exp.payer.isMe ? "You" : exp.payer.name;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CategoryTheme.getBgColor(exp.category),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CategoryTheme.getIcon(exp.category),
                              color: CategoryTheme.getColor(exp.category),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exp.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Paid by $payerName • ${exp.participants.length} people",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              exp.amount.toINR(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () {
                              setState(() {
                                tripExpenses.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (tripExpenses.isNotEmpty) ...[
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
                      "Settlement Breakdown",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8BC24A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Live Preview",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Review each person's exact give & get amounts before saving:",
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                ...settlements.map((s) => _buildPersonPreviewCard(s)),
              ],
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => handleSaveGroupTrip(participants),
              icon: const Icon(Icons.done_all_rounded,
                  color: Colors.white, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Save Trip & Update Ledgers (${totalTripSpent.toINR()})",
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PERSON-CENTRIC PREVIEW CARD BUILDER (USER'S IDEA)
  // ────────────────────────────────────────────────────────────
  Widget _buildPersonPreviewCard(PersonSettlement s) {
    final isMe = s.person.isMe;
    final name = isMe ? "You ($currentUserNameClean)" : s.person.name;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (s.willGet) {
      badgeBg = const Color(0xFFE8F5E9);
      badgeText = const Color(0xFF2E7D32);
      badgeLabel = "Gets ${s.netBalance.toINR()}";
    } else if (s.willGive) {
      badgeBg = const Color(0xFFFFEBEE);
      badgeText = const Color(0xFFC62828);
      badgeLabel = "Owes ${s.netBalance.abs().toINR()}";
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = const Color(0xFF64748B);
      badgeLabel = "Settled Up";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFF8BC24A).withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: isMe ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isMe
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF1E293B),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          if (s.giveLines.isNotEmpty) ...[
            ...s.giveLines.map((line) {
              final toName =
                  line.otherPerson.isMe ? "You" : line.otherPerson.name;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded,
                        color: Color(0xFFC62828), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Give ${line.amount.toINR()} to $toName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ),
                    if (line.reason.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          line.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],

          if (s.getLines.isNotEmpty) ...[
            ...s.getLines.map((line) {
              final fromName =
                  line.otherPerson.isMe ? "You" : line.otherPerson.name;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded,
                        color: Color(0xFF2E7D32), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Get ${line.amount.toINR()} from $fromName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    if (line.reason.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          line.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],

          if (s.giveLines.isEmpty && s.getLines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "✨ All balanced. No pending payments.",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Paid: ${s.totalPaid.toINR()}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Consumed: ${s.totalConsumed.toINR()}",
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get currentUserNameClean =>
      _currentUserName.isNotEmpty ? _currentUserName : "You";

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
}
