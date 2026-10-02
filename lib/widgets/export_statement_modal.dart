import 'package:fin_track/utils/money.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

enum DatePreset { thisMonth, last3Months, financialYear, custom }

enum TransactionTypeFilter { all, debitsOnly, creditsOnly }

/// Opens the modern FinTrack Export Financial Statement bottom sheet modal.
Future<void> showExportStatementModal({
  required BuildContext context,
  required String userName,
  required String phoneNumber,
  required List<Map<String, dynamic>> records,
  String initialCategory = "All",
  DateTimeRange? initialDateRange,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ExportStatementModalContent(
      userName: userName,
      phoneNumber: phoneNumber,
      allRecords: records,
      initialCategory: initialCategory,
      initialDateRange: initialDateRange,
    ),
  );
}

class _ExportStatementModalContent extends StatefulWidget {
  final String userName;
  final String phoneNumber;
  final List<Map<String, dynamic>> allRecords;
  final String initialCategory;
  final DateTimeRange? initialDateRange;

  const _ExportStatementModalContent({
    required this.userName,
    required this.phoneNumber,
    required this.allRecords,
    required this.initialCategory,
    this.initialDateRange,
  });

  @override
  State<_ExportStatementModalContent> createState() =>
      _ExportStatementModalContentState();
}

class _ExportStatementModalContentState
    extends State<_ExportStatementModalContent> {
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _cardBg = Color(0xFFF8FAFC);
  static const Color _borderGrey = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);

  late DatePreset _selectedPreset;
  late DateTime _startDate;
  late DateTime _endDate;
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;

  bool _includeCategoryBreakdown = true;
  bool _includeRunningBalance = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialDateRange != null) {
      _selectedPreset = DatePreset.custom;
      _startDate = widget.initialDateRange!.start;
      _endDate = widget.initialDateRange!.end;
    } else {
      _selectedPreset = DatePreset.thisMonth;
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  void _applyDatePreset(DatePreset preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case DatePreset.thisMonth:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case DatePreset.last3Months:
          _startDate = DateTime(now.year, now.month - 2, 1);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case DatePreset.financialYear:
          if (now.month >= 4) {
            _startDate = DateTime(now.year, 4, 1);
          } else {
            _startDate = DateTime(now.year - 1, 4, 1);
          }
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case DatePreset.custom:
          // Keep current custom range until picker is opened
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _startDate.isBefore(DateTime(now.year - 5))
            ? DateTime(now.year, now.month, 1)
            : (_startDate.isAfter(_endDate) ? _endDate : _startDate),
        end: _endDate.isAfter(DateTime(now.year + 1)) ? now : _endDate,
      ),
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

    if (picked != null) {
      setState(() {
        _selectedPreset = DatePreset.custom;
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  List<Map<String, dynamic>> _filterRecords() {
    return widget.allRecords.where((item) {
      // 1. Date Filter
      final dt =
          (item["_parsedDate"] as DateTime?) ?? DateHelper.parse(item["Date"]);
      if (dt == null) {
        return false;
      }
      if (dt.isBefore(_startDate) || dt.isAfter(_endDate)) {
        return false;
      }

      // 2. Transaction Type Filter
      final mode = (item["Payment_Mode"] ?? "").toString();
      final isIncome = mode == "Add CASH" || mode == "Add Online";
      if (_typeFilter == TransactionTypeFilter.debitsOnly && isIncome) {
        return false;
      }
      if (_typeFilter == TransactionTypeFilter.creditsOnly && !isIncome) {
        return false;
      }

      // 3. Category Filter
      if (widget.initialCategory != "All") {
        final cat = (item["Category"] ?? "").toString();
        if (cat != widget.initialCategory) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _generatePdf({required bool isShare}) async {
    final filtered = _filterRecords();
    if (filtered.isEmpty) {
      Fluttertoast.showToast(
        msg: "No transactions match your selected filters.",
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Compute financial totals in integer paise
      int totalIncomePaise = 0;
      int totalExpensePaise = 0;
      int addCashPaise = 0;
      int spentCashPaise = 0;
      int addOnlinePaise = 0;
      int spentOnlinePaise = 0;

      for (final r in filtered) {
        final mode = (r["Payment_Mode"] ?? "").toString();
        final amtPaise = Money.paise(r["Amount"]);
        if (mode == "Add CASH") {
          totalIncomePaise += amtPaise;
          addCashPaise += amtPaise;
        } else if (mode == "Add Online") {
          totalIncomePaise += amtPaise;
          addOnlinePaise += amtPaise;
        } else if (mode == "Spent Cash") {
          totalExpensePaise += amtPaise;
          spentCashPaise += amtPaise;
        } else if (mode == "Spent Online") {
          totalExpensePaise += amtPaise;
          spentOnlinePaise += amtPaise;
        } else {
          totalExpensePaise += amtPaise;
        }
      }

      final double totalIncome = totalIncomePaise / 100.0;
      final double totalExpense = totalExpensePaise / 100.0;
      final double addCash = addCashPaise / 100.0;
      final double spentCash = spentCashPaise / 100.0;
      final double addOnline = addOnlinePaise / 100.0;
      final double spentOnline = spentOnlinePaise / 100.0;
      final currentBalance = totalIncome - totalExpense;
      String filterLabel = widget.initialCategory;
      if (_typeFilter == TransactionTypeFilter.debitsOnly) {
        filterLabel += " (Debits Only)";
      } else if (_typeFilter == TransactionTypeFilter.creditsOnly) {
        filterLabel += " (Credits Only)";
      }

      Fluttertoast.showToast(
        msg: isShare
            ? "Preparing statement for sharing..."
            : "Opening statement preview...",
      );

      await ExportService.exportPassbookPdf(
        userName: widget.userName.isNotEmpty
            ? widget.userName
            : "Account Holder",
        phoneNumber: widget.phoneNumber,
        records: filtered,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        currentBalance: currentBalance,
        addCash: addCash,
        spentCash: spentCash,
        addOnline: addOnline,
        spentOnline: spentOnline,
        filterCategory: filterLabel,
        startDate: _startDate,
        endDate: _endDate,
        includeCategoryBreakdown: _includeCategoryBreakdown,
        includeRunningBalance: _includeRunningBalance,
        isShare: isShare,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to generate statement: $e");
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterRecords();

    double previewInflow = 0.0;
    double previewOutflow = 0.0;
    for (final r in filtered) {
      final mode = (r["Payment_Mode"] ?? "").toString();
      final amt = Money.rupees(r["Amount"]);
      if (mode == "Add CASH" || mode == "Add Online") {
        previewInflow = Money.sum([previewInflow, amt]);
      } else {
        previewOutflow = Money.sum([previewOutflow, amt]);
      }
    }
    final previewNet = previewInflow - previewOutflow;

    final periodLabel =
        "${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}";

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: _primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Export Financial Statement",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Bank-grade A4 PDF transaction report",
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _textMuted),
                  tooltip: "Close",
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _borderGrey),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DATE RANGE SECTION
                  _buildSectionHeader("DATE RANGE"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip("This Month", DatePreset.thisMonth),
                      _buildPresetChip("Last 3 Months", DatePreset.last3Months),
                      _buildPresetChip(
                        "Financial Year",
                        DatePreset.financialYear,
                      ),
                      _buildCustomChip(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. TRANSACTION TYPE FILTER SECTION
                  _buildSectionHeader("TRANSACTION FILTER"),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeFilterChip(
                          "All",
                          TransactionTypeFilter.all,
                          Icons.swap_horiz_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypeFilterChip(
                          "Debits Only",
                          TransactionTypeFilter.debitsOnly,
                          Icons.arrow_upward_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypeFilterChip(
                          "Credits Only",
                          TransactionTypeFilter.creditsOnly,
                          Icons.arrow_downward_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. LIVE SUMMARY PREVIEW CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFDCFCE7),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                  color: _darkGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "STATEMENT PREVIEW",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green.shade800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderGrey),
                              ),
                              child: Text(
                                "${filtered.length} entries",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          periodLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // Inflow
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Inflow",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "+${previewInflow.toINR()}",
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(height: 32, width: 1, color: _borderGrey),
                            const SizedBox(width: 12),
                            // Outflow
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Outflow",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "-${previewOutflow.toINR()}",
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(height: 32, width: 1, color: _borderGrey),
                            const SizedBox(width: 12),
                            // Net Balance
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Net Balance",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    previewNet.toINR(),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: previewNet >= 0
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. DOCUMENT OPTIONS SECTION
                  _buildSectionHeader("DOCUMENT OPTIONS"),
                  const SizedBox(height: 8),
                  _buildOptionToggle(
                    icon: Icons.pie_chart_outline_rounded,
                    title: "Include Category Breakdown",
                    subtitle: "Categorical spending distribution & shares",
                    value: _includeCategoryBreakdown,
                    onChanged: (v) =>
                        setState(() => _includeCategoryBreakdown = v),
                  ),
                  const SizedBox(height: 6),
                  _buildOptionToggle(
                    icon: Icons.account_balance_wallet_outlined,
                    title: "Include Running Balance Column",
                    subtitle:
                        "Calculates progressive ledger after each transaction",
                    value: _includeRunningBalance,
                    onChanged: (v) =>
                        setState(() => _includeRunningBalance = v),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Fixed Action Buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _borderGrey)),
            ),
            child: _isGenerating
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _primaryGreen,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Generating Statement PDF...",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Preview PDF Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textDark,
                            side: const BorderSide(
                              color: _borderGrey,
                              width: 1.3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 19,
                            color: _darkGreen,
                          ),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Preview PDF",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          onPressed: () => _generatePdf(isShare: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Download / Share Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.share_rounded,
                            size: 19,
                            color: Colors.white,
                          ),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Download / Share",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          onPressed: () => _generatePdf(isShare: true),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildPresetChip(String label, DatePreset preset) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyDatePreset(preset),
      selectedColor: const Color(0xFFDCFCE7),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? _darkGreen : _textDark,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ),
      side: BorderSide(
        color: isSelected ? _primaryGreen : _borderGrey,
        width: isSelected ? 1.4 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: isSelected,
      checkmarkColor: _darkGreen,
    );
  }

  Widget _buildCustomChip() {
    final isCustom = _selectedPreset == DatePreset.custom;
    return ActionChip(
      avatar: Icon(
        Icons.calendar_month_rounded,
        size: 16,
        color: isCustom ? _darkGreen : _textMuted,
      ),
      label: Text(
        isCustom
            ? "${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}"
            : "Custom Range",
      ),
      onPressed: _pickCustomRange,
      backgroundColor: isCustom ? const Color(0xFFDCFCE7) : Colors.white,
      labelStyle: TextStyle(
        color: isCustom ? _darkGreen : _textDark,
        fontWeight: isCustom ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ),
      side: BorderSide(
        color: isCustom ? _primaryGreen : _borderGrey,
        width: isCustom ? 1.4 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildTypeFilterChip(
    String label,
    TransactionTypeFilter filter,
    IconData icon,
  ) {
    final isSelected = _typeFilter == filter;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _typeFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryGreen : _borderGrey,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? _darkGreen : _textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _darkGreen : _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _darkGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: _primaryGreen,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
