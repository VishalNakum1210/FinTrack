import 'dart:async';
import 'package:fin_track/friends_pages/add_friend_spent.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
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
    setState(() => _isLoading = true);
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
    final amountCtrl = TextEditingController(text: record['Amount']?.toString() ?? '');
    final descCtrl = TextEditingController(text: record['Description']?.toString() ?? '');

    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Transaction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descCtrl,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: 'Description',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8BC24A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) return;
    final newAmount = amountCtrl.text.trim();
    final newDesc = descCtrl.text.trim();
    if (newAmount.isEmpty) return;

    try {
      final ref = FirebaseDatabase.instance
          .ref('Friends/$_userPhone/${widget.friendNumber}/Records/${record['key']}');
      await ref.update({'Amount': newAmount, 'Description': newDesc});

      final oldAmt = (double.tryParse(record['Amount']?.toString() ?? '0') ?? 0.0).round();
      final newAmt = (double.tryParse(newAmount) ?? 0.0).round();
      final diff = newAmt - oldAmt;
      if (diff != 0) {
        final isGive = record['Type'] == 'Take Money From Friend';
        final friendRef = FirebaseDatabase.instance.ref('Friends/$_userPhone/${widget.friendNumber}');
        if (!mounted) return;
        await context.read<FriendProvider>().adjustLedger(
          friendRef: friendRef,
          field: isGive ? 'total_give' : 'total_get',
          delta: diff,
        );
      }
      Fluttertoast.showToast(msg: 'Record updated');
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
    const Color primaryColor = Color(0xFF8BC24A);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(
          _friendData['friend_name'] ?? widget.friendName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Export PDF Ledger',
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _exportPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddFriendExpenses(friendNumber: widget.friendNumber),
            ),
          ) ?? false;
          if (result == true) _startStream();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _friendData.isEmpty
              ? const Center(child: Text('Friend Not Found'))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(15),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8BC24A), Color(0xFF7CB342)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: .35),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white,
                            child: Text(
                              (_friendData['friend_name'] ?? 'F').toString().isNotEmpty
                                  ? (_friendData['friend_name'] ?? 'F').toString()[0].toUpperCase()
                                  : 'F',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (_friendData['friend_name'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (_friendData['friend_number'] ?? '').toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'You Get',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _totalGet.toINR(compactSymbol: true),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'You Want to Give',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _totalGive.toINR(compactSymbol: true),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('Net Balance', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text(
                            (_totalGet - _totalGive).abs().toINR(compactSymbol: true),
                            style: TextStyle(
                              color: (_totalGet >= _totalGive) ? Colors.green : Colors.red,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Transactions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _records.isEmpty
                          ? const Center(child: Text('No Records'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 25, left: 10, right: 10),
                              itemCount: _records.length,
                              itemBuilder: (context, index) {
                                final record = _records[index];
                                final isGive = record['Type'] == 'Take Money From Friend';
                                final amount = (double.tryParse(record['Amount']?.toString() ?? '0') ?? 0.0).round();
                                final key = (record['key'] ?? '').toString();

                                return InkWell(
                                  onTap: () async {
                                    final confirmed = await showDeleteConfirmDialog(
                                      context,
                                      title: 'Delete Record',
                                      message: 'Are you sure you want to delete this record?',
                                    );
                                    if (confirmed == true && key.isNotEmpty) {
                                      await _deleteRecord(key, isGive, amount);
                                    }
                                  },
                                  onLongPress: () => _editRecord(record),
                                  child: _transactionCard(
                                    amount: amount.toINR(compactSymbol: true),
                                    title: (record['Type'] ?? '').toString(),
                                    note: (record['Description'] ?? '').toString(),
                                    date: (record['Date'] ?? '').toString(),
                                    isGive: isGive,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  static Widget _transactionCard({
    required String amount,
    required String title,
    required String note,
    required String date,
    required bool isGive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isGive
                ? Colors.red.withValues(alpha: .12)
                : Colors.green.withValues(alpha: .12),
            child: Image.asset(
              isGive ? 'assets/image/SpentPic.png' : 'assets/image/GetPic.png',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isGive ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hold to edit',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
