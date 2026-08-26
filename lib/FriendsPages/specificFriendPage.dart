import 'package:FinTrack/FriendsPages/addFriendSpent.dart';
import 'package:FinTrack/GetInformation/GetSpecificFriendDetails.dart';
import 'package:FinTrack/providers/friend_provider.dart';
import 'package:FinTrack/providers/user_provider.dart';
import 'package:FinTrack/services/export_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Specificfriendpage extends StatefulWidget {
  final String friend_number;
  const Specificfriendpage({super.key, required this.friend_number});

  @override
  State<Specificfriendpage> createState() => _SpecificFriendPageState();
}

class _SpecificFriendPageState extends State<Specificfriendpage> {
  List<Map<String, dynamic>> friendDetails = [];
  List<Map<String, dynamic>> expensesRecords = [];
  bool isLoading = true;
  int totalGet = 0;
  int totalGive = 0;

  Future<void> getDetails() async {
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String phoneNumber = sp.getString("phone_number") ?? "";
      if (phoneNumber.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      friendDetails = await getSpecificFriendDetails(
        phoneNumber,
        widget.friend_number,
      );

      expensesRecords.clear();

      if (friendDetails.isNotEmpty) {
        totalGet = int.tryParse(friendDetails[0]["total_get"]?.toString() ?? '0') ?? 0;
        totalGive = int.tryParse(friendDetails[0]["total_give"]?.toString() ?? '0') ?? 0;

        if (friendDetails[0].containsKey("Records") && friendDetails[0]["Records"] is Map) {
          friendDetails[0]["Records"].forEach((key, value) {
            if (value is Map) {
              expensesRecords.add(Map<String, dynamic>.from(value));
            }
          });

          expensesRecords.sort((a, b) {
            DateTime? parseDate(String? d) {
              if (d == null || d.isEmpty) return null;
              try {
                return DateFormat('d/M/yyyy').parse(d);
              } catch (_) {
                return DateTime.tryParse(d);
              }
            }

            final dateA = parseDate(a["Date"]);
            final dateB = parseDate(b["Date"]);

            if (dateA != null && dateB != null) {
              final cmp = dateB.compareTo(dateA);
              if (cmp != 0) return cmp;
            } else if (dateA != null) {
              return -1;
            } else if (dateB != null) {
              return 1;
            }

            final tA = a["timestamp"] is int ? a["timestamp"] as int : 0;
            final tB = b["timestamp"] is int ? b["timestamp"] as int : 0;
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
      SharedPreferences sp = await SharedPreferences.getInstance();
      String userNumber = sp.getString("phone_number") ?? "";

      if (userNumber.isNotEmpty && friendDetails.isNotEmpty && mounted) {
        await context.read<FriendProvider>().deleteFriendTransaction(
          userPhone: userNumber,
          friendNumber: friendDetails[0]["friend_number"] ?? widget.friend_number,
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
    final friendNum = friendDetails[0]["friend_number"] ?? widget.friend_number;
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
  void initState() {
    super.initState();
    getDetails();
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
                  AddFriendExpenses(friend_number: widget.friend_number),
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
                                final amount = int.tryParse(record["Amount"]?.toString() ?? '0') ?? 0;
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
