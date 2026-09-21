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
  const Specificfriendpage({super.key, required this.friendNumber, required this.friendName});

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

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async {
    await _sub?.cancel();
    _sub = null;

    _userPhone = await SessionManager.getPhoneNumber() ?? '';
    if (_userPhone.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final ref = FirebaseDatabase.instance.ref('Friends/$_userPhone/${widget.friendNumber}');
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
        });
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  int get _totalGet => (double.tryParse(_friendData['total_get']?.toString() ?? '0') ?? 0.0).round();
  int get _totalGive => (double.tryParse(_friendData['total_give']?.toString() ?? '0') ?? 0.0).round();

  Future<void> _deleteRecord(String key, bool isGive, int amount) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      if (!mounted) return;
      await context.read<FriendProvider>().deleteFriendTransaction(
            userPhone: _userPhone,
            friendNumber: widget.friendNumber,
            recordKey: key,
            isGive: isGive,
            amount: amount,
          );
      Fluttertoast.showToast(msg: 'Record deleted');
    } catch (e) {
      Fluttertoast.showToast(msg: '$e');
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

    try {
      final ref = FirebaseDatabase.instance
          .ref('Friends/$_userPhone/${widget.friendNumber}/Records/${record['key']}');
      await ref.update({'Amount': newAmount, 'Description': newDesc});

      final oldAmt = (double.tryParse(record['Amount']?.toString() ?? '0') ?? 0.0).round();
      final newAmt = (double.tryParse(newAmount) ?? 0.0).round();
      final diff = newAmt - oldAmt;
      if (diff != 0 && mounted) {
        final isGive = record['Type'] == 'Take Money From Friend';
        final friendRef = FirebaseDatabase.instance.ref('Friends/$_userPhone/${widget.friendNumber}');
        await context.read<FriendProvider>().adjustLedger(
              friendRef: friendRef,
              field: isGive ? 'total_give' : 'total_get',
              delta: diff,
            );
      }
      Fluttertoast.showToast(msg: 'Transaction updated');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update: $e');
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

  @override
  Widget build(BuildContext context) {
    final friendName = (_friendData['friend_name'] ?? widget.friendName).toString();
    final friendNumber = (_friendData['friend_number'] ?? widget.friendNumber).toString();
    final net = _totalGet - _totalGive;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              friendName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              friendNumber,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export PDF Ledger',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: primaryGreen, size: 20),
            ),
            onPressed: _exportPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "friend_fab",
        backgroundColor: primaryGreen,
        elevation: 4,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFriendExpenses(friendNumber: widget.friendNumber),
            ),
          ) ?? false;
          if (result == true) _startStream();
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text('Add Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _friendData.isEmpty
              ? const Center(child: Text('Friend Not Found'))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HERO FRIEND PROFILE CARD
                      _buildHeroFriendCard(friendName, friendNumber),
                      const SizedBox(height: 14),

                      // 2. SIDE-BY-SIDE METRICS (You Get vs You Give)
                      _buildDualMetricsCard(),
                      const SizedBox(height: 12),

                      // 3. NET SETTLEMENT STATUS CARD
                      _buildNetSettlementCard(net),
                      const SizedBox(height: 20),

                      // 4. TRANSACTION HISTORY HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            "${_records.length} ${_records.length == 1 ? 'entry' : 'entries'}",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 5. TRANSACTION LIST
                      if (_records.isEmpty)
                        _buildEmptyHistory()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            final isGive = record['Type'] == 'Take Money From Friend';
                            final amount =
                                (double.tryParse(record['Amount']?.toString() ?? '0') ?? 0.0).round();
                            final key = (record['key'] ?? '').toString();

                            return _buildRecordCard(
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

  Widget _buildHeroFriendCard(String name, String number) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8BC24A), Color(0xFF689F38)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF689F38).withValues(alpha: .30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'F',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualMetricsCard() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF2E7D32)),
                    SizedBox(width: 4),
                    Text(
                      'You Will Get',
                      style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _totalGet.toINR(),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFC62828)),
                    SizedBox(width: 4),
                    Text(
                      'You Will Give',
                      style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _totalGive.toINR(),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.w800,
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

  Widget _buildNetSettlementCard(int net) {
    final isOwed = net >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Net Balance',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                net == 0 ? "All Settled ✓" : net.abs().toINR(),
                style: TextStyle(
                  color: net == 0
                      ? const Color(0xFF64748B)
                      : isOwed
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOwed ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              net == 0
                  ? "0 Balance"
                  : isOwed
                      ? "Owed to you"
                      : "You owe",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isOwed ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard({
    required Map<String, dynamic> record,
    required bool isGive,
    required int amount,
    required String keyStr,
  }) {
    final title = (record['Type'] ?? '').toString();
    final note = (record['Description'] ?? '').toString();
    final date = (record['Date'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editRecord(record),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Direction icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isGive ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isGive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: isGive ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        DateHelper.formatDisplay(date),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Amount & Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isGive ? "-${amount.toINR()}" : "+${amount.toINR()}",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: isGive ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                      onPressed: () => _editRecord(record),
                      tooltip: "Edit",
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      onPressed: () async {
                        final confirmed = await showDeleteConfirmDialog(
                          context,
                          title: 'Delete Record',
                          message: 'Are you sure you want to delete this record?',
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
          ),
        ),
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          SizedBox(height: 4),
          Text(
            'Tap "+ Add Entry" below to record a loan, repayment, or shared bill.',
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
    _amountCtrl = TextEditingController(text: widget.record['Amount']?.toString() ?? '');
    _descCtrl = TextEditingController(text: widget.record['Description']?.toString() ?? '');
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            maxLength: 10,
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Note / Description',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amt = _amountCtrl.text.trim();
              final desc = _descCtrl.text.trim();
              if (amt.isEmpty) {
                Fluttertoast.showToast(msg: 'Please enter an amount');
                return;
              }
              Navigator.pop(context, {'amount': amt, 'desc': desc});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      ),
    );
  }
}

