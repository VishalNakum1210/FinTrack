import 'package:FinTrack/FriendsPages/add_friend_spent.dart';
import 'package:FinTrack/GetInformation/get_specific_friend_details.dart';
import 'package:FinTrack/GetInformation/session_manager.dart';
import 'package:FinTrack/providers/friend_provider.dart';
import 'package:FinTrack/providers/user_provider.dart';
import 'package:FinTrack/services/export_service.dart';
import 'package:FinTrack/utils/date_helper.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class Specificfriendpage extends StatefulWidget {
  final String friendNumber;
  final String friendName;
  const Specificfriendpage({super.key, required this.friendNumber, required this.friendName});

  @override
  State<Specificfriendpage> createState() => _SpecificfriendpageState();
}

class _SpecificfriendpageState extends State<Specificfriendpage> {
  int totalGet = 0;
  int totalGive = 0;
  List<Map<dynamic, dynamic>> friendDetails = [];
  List<Map<String, dynamic>> expensesRecords = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  Future<void> getDetails() async {
    try {
      String phoneNumber = await SessionManager.getPhoneNumber() ?? "";
      if (phoneNumber.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      friendDetails = await getSpecificFriendDetails(
        phoneNumber,
        widget.friendNumber,
      );

      expensesRecords.clear();

      if (friendDetails.isNotEmpty) {
        totalGet = (double.tryParse(friendDetails[0]["total_get"]?.toString() ?? '0') ?? 0.0).round();
        totalGive = (double.tryParse(friendDetails[0]["total_give"]?.toString() ?? '0') ?? 0.0).round();

        if (friendDetails[0].containsKey("Records") && friendDetails[0]["Records"] is Map) {
          friendDetails[0]["Records"].forEach((key, value) {
            if (value is Map) {
              final map = Map<String, dynamic>.from(value);
              map["_parsedDate"] = DateHelper.parse(map["Date"]);
              expensesRecords.add(map);
            }
          });

          expensesRecords.sort((a, b) {
            final DateTime? dateA = (a["_parsedDate"] as DateTime?) ?? DateHelper.parse(a["Date"]);
            final DateTime? dateB = (b["_parsedDate"] as DateTime?) ?? DateHelper.parse(b["Date"]);

            if (dateA != null && dateB != null) {
              final cmp = dateB.compareTo(dateA);
              if (cmp != 0) return cmp;
            } else if (dateA != null) {
              return -1;
            } else if (dateB != null) {
              return 1;
            }

            final tA = (a["timestamp"] as num?)?.toInt() ?? 0;
            final tB = (b["timestamp"] as num?)?.toInt() ?? 0;
            return tB.compareTo(tA);
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteRecord(String key, bool con, int amount) async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      String userNumber = await SessionManager.getPhoneNumber() ?? "";

      if (userNumber.isNotEmpty && friendDetails.isNotEmpty && mounted) {
        await context.read<FriendProvider>().deleteFriendTransaction(
          userPhone: userNumber,
          friendNumber: friendDetails[0]["friend_number"] ?? widget.friendNumber,
          recordKey: key,
          isGive: con,
          amount: amount,
        );

        Fluttertoast.showToast(msg: "Record deleted successfully");
        expensesRecords.clear();
        await getDetails();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "$e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> exportFriendLedgerToPdf() async {
    if (friendDetails.isEmpty) {
      Fluttertoast.showToast(msg: "No friend details to export");
      return;
    }
    final friendName = friendDetails[0]["friend_name"] ?? "Friend";
    final friendNum = friendDetails[0]["friend_number"] ?? widget.friendNumber;
    final userProvider = context.read<UserProvider>();
    final userName = userProvider.name.isNotEmpty ? userProvider.name : "User";

    Fluttertoast.showToast(msg: "Generating PDF Statement...");
    await ExportService.exportFriendLedgerPdf(
      userName: userName,
      friendName: friendName,
      friendNumber: friendNum,
      totalGet: totalGet,
      totalGive: totalGive,
      records: expensesRecords,
    );
  }

  String formatIndianNumber(int number) {
    return NumberFormat('#,##,##0', 'en_IN').format(number);
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
          (!isLoading && friendDetails.isNotEmpty) ? (friendDetails[0]["friend_name"] ?? "Friend") : "Friend",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: "Export PDF Ledger",
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: exportFriendLedgerToPdf,
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
              builder: (context) =>
                  AddFriendExpenses(friendNumber: widget.friendNumber),
            ),
          ) ?? false;

          if (result == true) {
            getDetails();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Add"),
      ),

      body: (isLoading)
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : (friendDetails.isEmpty)
              ? const Center(child: Text("Friend Not Found"))
              : Column(
                  children: [
                    // Profile Card
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
                              (friendDetails[0]["friend_name"] ?? "F").toString().isNotEmpty
                                  ? (friendDetails[0]["friend_name"] ?? "F").toString()[0].toUpperCase()
                                  : "F",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            (friendDetails[0]["friend_name"] ?? "").toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            (friendDetails[0]["friend_number"] ?? "").toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    // Get / Give Cards
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
                                    "You Get",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'en_IN',
                                      symbol: '₹',
                                      decimalDigits: 0,
                                    ).format(totalGet),
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
                                    "You Want to Give",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'en_IN',
                                      symbol: '₹',
                                      decimalDigits: 0,
                                    ).format(totalGive),
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

                    // Net Balance
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
                          const Text(
                            "Net Balance",
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            NumberFormat.currency(
                              locale: 'en_IN',
                              symbol: '₹',
                              decimalDigits: 0,
                            ).format((totalGet - totalGive).abs()),
                            style: TextStyle(
                              color: (totalGet >= totalGive) ? Colors.green : Colors.red,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Transactions Header
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Transactions",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Transaction List
                    Expanded(
                      child: expensesRecords.isEmpty
                          ? const Center(child: Text("No Records"))
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                bottom: 25,
                                left: 10,
                                right: 10,
                              ),
                              itemCount: expensesRecords.length,
                              itemBuilder: (context, index) {
                                final record = expensesRecords[index];
                                final isGive = record["Type"] == "Take Money From Friend";
                                final amount = (double.tryParse(record["Amount"]?.toString() ?? '0') ?? 0.0).round();
                                final key = (record["key"] ?? "").toString();

                                return InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: const Text("Delete Record"),
                                        content: const Text(
                                          "Are you sure you want to delete this record?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              if (key.isNotEmpty) {
                                                await deleteRecord(
                                                  key,
                                                  isGive,
                                                  amount,
                                                );
                                              }
                                            },
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: _transactionCard(
                                    amount: NumberFormat.currency(
                                      locale: 'en_IN',
                                      symbol: '₹',
                                      decimalDigits: 0,
                                    ).format(amount),
                                    title: (record["Type"] ?? "").toString(),
                                    note: (record["Description"] ?? "").toString(),
                                    date: (record["Date"] ?? "").toString(),
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
              isGive ? "assets/image/SpentPic.png" : "assets/image/GetPic.png",
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  note,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),

                const SizedBox(height: 4),

                Text(
                  date,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isGive ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
