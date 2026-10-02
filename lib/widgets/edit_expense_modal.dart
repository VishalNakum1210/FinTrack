import 'package:fin_track/utils/money.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

Future<bool?> showEditExpenseModal({
  required BuildContext context,
  required Map<String, dynamic> record,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => EditExpenseModalContent(record: record),
  );
}

class EditExpenseModalContent extends StatefulWidget {
  final Map<String, dynamic> record;

  const EditExpenseModalContent({super.key, required this.record});

  @override
  State<EditExpenseModalContent> createState() =>
      _EditExpenseModalContentState();
}

class _EditExpenseModalContentState extends State<EditExpenseModalContent> {
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _borderGrey = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;

  late String _selectedCategory;
  late String _selectedMode;
  late DateTime _selectedDate;
  bool _isSaving = false;

  final List<String> _categories = const [
    "Food",
    "Shopping",
    "Transport",
    "Education",
    "HealthCare",
    "Entertainment",
    "Add Money",
    "Other",
  ];

  final List<String> _paymentModes = const [
    "Spent Online",
    "Spent Cash",
    "Add Online",
    "Add CASH",
    "Owed",
  ];

  String _originalPaymentMode = "";

  @override
  void initState() {
    super.initState();
    final rawAmount = (widget.record["Amount"] ?? "").toString();
    final rawDesc = (widget.record["Description"] ?? "").toString();
    final rawCategory = (widget.record["Category"] ?? "Other").toString();
    final storedMode = (widget.record["Payment_Mode"] ?? "").toString();
    _originalPaymentMode = storedMode;
    final rawMode = storedMode.startsWith('Owed to ') ? 'Owed' : storedMode;
    final rawDate = (widget.record["Date"] ?? "").toString();

    _amountCtrl = TextEditingController(text: rawAmount);
    _descCtrl = TextEditingController(text: rawDesc);

    _selectedCategory = _categories.contains(rawCategory)
        ? rawCategory
        : "Other";
    _selectedMode = _paymentModes.contains(rawMode) ? rawMode : '';
    _selectedDate = DateHelper.parse(rawDate) ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime(2000))
          ? DateTime(2000)
          : (_selectedDate.isAfter(DateTime.now())
                ? DateTime.now()
                : _selectedDate),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
              onSurface: _textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_paymentModes.contains(_selectedMode)) {
      Fluttertoast.showToast(
        msg: 'Please select a payment mode for this record.',
      );
      return;
    }
    final amountText = _amountCtrl.text.trim();
    final descText = _descCtrl.text.trim();

    final parsedAmount = (Money.tryPaise(amountText) == null
        ? null
        : Money.rupees(amountText));
    if (parsedAmount == null || parsedAmount <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid amount");
      return;
    }

    final key = (widget.record["key"] ?? "").toString();
    if (key.isEmpty) {
      Fluttertoast.showToast(msg: "Cannot update record: missing ID");
      return;
    }

    final expenseProvider = context.read<ExpenseProvider>();
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: "User session expired. Please re-login.");
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    final dateStr = DateFormat("d/M/yyyy").format(_selectedDate);
    final modeToSave =
        (_selectedMode == 'Owed' && _originalPaymentMode.startsWith('Owed to '))
            ? _originalPaymentMode
            : _selectedMode;

    final success = await expenseProvider.updateExpense(
      phoneNumber: phone,
      key: key,
      amount: parsedAmount.toStringAsFixed(
        parsedAmount.truncateToDouble() == parsedAmount ? 0 : 2,
      ),
      category: _selectedCategory,
      paymentMode: modeToSave,
      description: descText,
      date: dateStr,
    );

    if (mounted) setState(() => _isSaving = false);

    if (success) {
      Fluttertoast.showToast(msg: "Transaction updated successfully");
      if (mounted) Navigator.pop(context, true);
    } else {
      Fluttertoast.showToast(
        msg: expenseProvider.lastError ?? "Unable to update transaction",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: _darkGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Edit Transaction",
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                          ),
                        ),
                        Text(
                          "Update amount, category or payment mode",
                          style: TextStyle(fontSize: 11.5, color: _textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24, color: _borderGrey),

            // 1. Amount Input
            const Text(
              "Amount",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    "₹",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _darkGreen,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _primaryGreen,
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Category Selector
            const Text(
              "Category",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                final catColor = CategoryTheme.getColor(cat);
                final catIcon = CategoryTheme.getIcon(cat);

                return InkWell(
                  onTap: () => setState(() => _selectedCategory = cat),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withValues(alpha: 0.15)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? catColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          catIcon,
                          size: 14,
                          color: isSelected ? catColor : _textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? catColor : _textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 3. Payment Mode Selector
            const Text(
              "Payment Mode",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentModes.map((mode) {
                final isSelected = mode == _selectedMode;
                final isIncome = mode.startsWith("Add");

                return InkWell(
                  onTap: () => setState(() => _selectedMode = mode),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isIncome
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE))
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? (isIncome
                                  ? _primaryGreen
                                  : const Color(0xFFEF5350))
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      mode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? (isIncome ? _darkGreen : const Color(0xFFC62828))
                            : _textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 4. Date Picker Row
            const Text(
              "Transaction Date",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderGrey),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: _primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat("dd MMMM yyyy").format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "Change",
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Description / Note
            const Text(
              "Description / Note (Optional)",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLength: 150,
              decoration: InputDecoration(
                counterText: "",
                hintText: "Enter note (e.g. Lunch, Groceries)",
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _primaryGreen,
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 6. Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
