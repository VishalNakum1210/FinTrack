import 'package:fin_track/utils/ledger_totals.dart';
import 'package:fin_track/utils/money.dart';
import 'dart:async';
import 'package:fin_track/friends_pages/add_friend_spent.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:fin_track/widgets/confirm_dialog.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class Specificfriendpage extends StatefulWidget {
  final String friendNumber;
  final String friendName;
  const Specificfriendpage({
    super.key,
    required this.friendNumber,
    required this.friendName,
  });

  @override
  State<Specificfriendpage> createState() => _SpecificfriendpageState();
}

class _SpecificfriendpageState extends State<Specificfriendpage> {
  static const Color primaryGreen = CategoryTheme.primaryGreen;
  StreamSubscription<DatabaseEvent>? _sub;
  String _userPhone = '';

  Map<String, dynamic> _friendData = {};
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _syncError = null;
      });
    }

    _userPhone = await SessionManager.getPhoneNumber() ?? '';
    if (_userPhone.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncError = 'Session expired. Please sign in again.';
        });
      }
      return;
    }

    final ref = FirebaseDatabase.instance.ref(
      'Friends/$_userPhone/${widget.friendNumber}',
    );
    _sub = ref.onValue.listen(
      (event) {
        if (!mounted) return;
        final Map<String, dynamic> data = {};
        final List<Map<String, dynamic>> records = [];

        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
          raw.forEach((k, v) {
            if (k == 'Records' && v is Map) {
              v.forEach((rk, rv) {
                if (rv is Map) {
                  final map = Map<String, dynamic>.from(rv);
                  map['key'] = rk;
                  map['_parsedDate'] = DateHelper.parse(map['Date']);
                  records.add(map);
                }
              });
            } else {
              data[k] = v;
            }
          });

          records.sort((a, b) {
            final DateTime? dA = a['_parsedDate'] as DateTime?;
            final DateTime? dB = b['_parsedDate'] as DateTime?;
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
        }

        setState(() {
          _friendData = data;
          _records = records;
          _isLoading = false;
          _syncError = null;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _syncError =
                'Unable to sync this ledger. Cached records may be out of date.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  double get _totalGet => LedgerTotals.fromRecords(_records).totalGet;
  double get _totalGive => LedgerTotals.fromRecords(_records).totalGive;

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return "F";
    final parts = clean
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  Future<void> _deleteRecord(String key, bool isGive, double amount) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      if (!mounted) return;
      final success = await context
          .read<FriendProvider>()
          .deleteFriendTransaction(
            userPhone: _userPhone,
            friendNumber: widget.friendNumber,
            recordKey: key,
            isGive: isGive,
            amount: amount,
          );
      if (success) {
        _records.removeWhere((r) => r['key'] == key);
        if (mounted) setState(() {});
      }
      Fluttertoast.showToast(
        msg: success ? 'Record deleted' : 'Unable to delete record',
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Unable to delete record');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditRecordBottomSheet(record: record),
    );

    if (result == null || !mounted) return;
    final newAmount = result['amount'] ?? '';
    final newDesc = result['desc'] ?? '';
    if (newAmount.isEmpty) return;

    final parsedPaise = Money.tryPaise(newAmount.replaceAll(',', '').trim());
    if (parsedPaise == null || parsedPaise <= 0) {
      Fluttertoast.showToast(msg: 'Please enter a valid amount');
      return;
    }
    final cleanNewAmount = Money.decimal(parsedPaise);

    try {
      final success = await context
          .read<FriendProvider>()
          .updateFriendTransaction(
            userPhone: _userPhone,
            friendNumber: widget.friendNumber,
            recordKey: record['key'].toString(),
            amount: cleanNewAmount,
            description: newDesc,
          );
      if (!success) {
        Fluttertoast.showToast(msg: 'Unable to update transaction');
        return;
      }
      record['Amount'] = cleanNewAmount;
      record['Description'] = newDesc;
      if (mounted) setState(() {});
      Fluttertoast.showToast(msg: 'Transaction updated');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Unable to update transaction');
    }
  }

  Future<void> _exportPdf() async {
    if (_friendData.isEmpty) {
      Fluttertoast.showToast(msg: 'No friend details to export');
      return;
    }
    final userProvider = context.read<UserProvider>();
    Fluttertoast.showToast(msg: 'Generating PDF Statement...');
    await ExportService.exportFriendLedgerPdf(
      userName: userProvider.name.isNotEmpty ? userProvider.name : 'User',
      friendName: _friendData['friend_name'] ?? widget.friendName,
      friendNumber: _friendData['friend_number'] ?? widget.friendNumber,
      totalGet: _totalGet,
      totalGive: _totalGive,
      records: _records,
    );
  }

  void _showSettleUpModal(String friendName, double net) {
    if (net == 0) {
      Fluttertoast.showToast(msg: "All settled up with $friendName!");
      return;
    }

    final isOwed = net > 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Settle Up with $friendName",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isOwed
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOwed
                            ? "Outstanding to Collect:"
                            : "Outstanding to Pay:",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isOwed
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                      Text(
                        net.abs().toINR(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isOwed
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final netDebtPaise = net.abs();
                      final initialAmt = netDebtPaise > 0
                          ? (netDebtPaise / 100.0).toStringAsFixed(2)
                          : null;
                      final initialType = isOwed
                          ? "Take Money From Friend"
                          : "Give Money To Friend";
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddFriendExpenses(
                            friendNumber: widget.friendNumber,
                            initialAmount: initialAmt,
                            initialType: initialType,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      isOwed
                          ? "Record Settlement Received"
                          : "Record Settlement Paid",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendName = (_friendData['friend_name'] ?? widget.friendName)
        .toString();
    final friendNumber = (_friendData['friend_number'] ?? widget.friendNumber)
        .toString();
    final net = _totalGet - _totalGive;
    final initials = _getInitials(friendName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          elevation: 0,
          backgroundColor: primaryGreen,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              // 56px Avatar Container
              Container(
                height: 48,
                width: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      friendName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "+91 $friendNumber",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Export PDF Ledger',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: _exportPdf,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _syncError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_syncError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _startStream,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _friendData.isEmpty
          ? const Center(child: Text('Friend Not Found'))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. BALANCED METRICS (You Get vs You Give)
                  _buildBalancedMetrics(),
                  const SizedBox(height: 16),

                  // 2. ACTION BAR (+ Add Transaction & Settle Up)
                  _buildActionBar(friendName, net),
                  const SizedBox(height: 20),

                  // 3. TRANSACTIONS LIST HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "${_records.length} ${_records.length == 1 ? 'record' : 'records'}",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. TRANSACTIONS LEDGER LIST
                  if (_records.isEmpty)
                    _buildEmptyHistory()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        final isGive =
                            record['Type'] == 'Take Money From Friend';
                        final amount = Money.rupees(record['Amount']);
                        final key = (record['key'] ?? '').toString();

                        return _buildTransactionCard(
                          record: record,
                          isGive: isGive,
                          amount: amount,
                          keyStr: key,
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBalancedMetrics() {
    return Row(
      children: [
        // You Get Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You Get',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _totalGet.toINR(),
                    style: const TextStyle(
                      fontSize: 24,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // You Give Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You Give',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _totalGive.toINR(),
                    style: const TextStyle(
                      fontSize: 24,
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(String friendName, double net) {
    return Row(
      children: [
        // + Add Transaction (Outlined Button)
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddFriendExpenses(friendNumber: widget.friendNumber),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: primaryGreen, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Add Transaction',
                  maxLines: 1,
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: primaryGreen, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Settle Up (Brand Green Filled Button)
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => _showSettleUpModal(friendName, net),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Settle Up',
                  maxLines: 1,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard({
    required Map<String, dynamic> record,
    required bool isGive,
    required double amount,
    required String keyStr,
  }) {
    final title = (record['Type'] ?? '').toString();
    final note = (record['Description'] ?? '').toString();
    final date = (record['Date'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Category / Direction Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isGive ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: isGive ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.isNotEmpty ? note : title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  DateHelper.formatDisplay(date),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Amount & Inline Action Icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 95),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    isGive ? "-${amount.toINR()}" : "+${amount.toINR()}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isGive
                          ? const Color(0xFFC62828)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Pencil Icon (Edit)
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () => _editRecord(record),
                tooltip: "Edit",
              ),
              const SizedBox(width: 6),
              // Trash Icon (Delete)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final confirmed = await showDeleteConfirmDialog(
                    context,
                    title: 'Delete Record',
                    message:
                        'Delete this record? If it belongs to a split, all linked bill and friend records will be deleted together.',
                  );
                  if (confirmed == true && keyStr.isNotEmpty) {
                    await _deleteRecord(keyStr, isGive, amount);
                  }
                },
                tooltip: "Delete",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.handshake_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'No Transactions Yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap "+ Add Transaction" above to record a loan, repayment, or shared bill.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _EditRecordBottomSheet extends StatefulWidget {
  final Map<String, dynamic> record;
  const _EditRecordBottomSheet({required this.record});

  @override
  State<_EditRecordBottomSheet> createState() => _EditRecordBottomSheetState();
}

class _EditRecordBottomSheetState extends State<_EditRecordBottomSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.record['Amount']?.toString() ?? '',
    );
    _descCtrl = TextEditingController(
      text: widget.record['Description']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF8BC24A);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Edit Ledger Record',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descCtrl,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: 'Note / Description',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final amt = _amountCtrl.text.replaceAll(',', '').trim();
                final desc = _descCtrl.text.trim();
                final parsedAmt = double.tryParse(amt);
                if (amt.isEmpty || parsedAmt == null || parsedAmt <= 0) {
                  Fluttertoast.showToast(msg: 'Please enter a valid amount');
                  return;
                }
                Navigator.pop(context, {'amount': amt, 'desc': desc});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
