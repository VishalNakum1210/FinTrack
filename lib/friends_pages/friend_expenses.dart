import 'package:fin_track/friends_pages/add_friends.dart';
import 'package:fin_track/friends_pages/specific_friend_page.dart';
import 'package:fin_track/friends_pages/split_bill_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/widgets/confirm_dialog.dart';
import 'package:fin_track/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FriendPage extends StatefulWidget {
  const FriendPage({super.key});

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriends();
    });
  }

  Future<void> _loadFriends({bool force = false}) async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (mounted && phone.isNotEmpty) {
      context.read<FriendProvider>().fetchFriends(phone, force: force);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> exportAllFriendsToPdf(List<Map<String, dynamic>> friends, int totalGet, int totalGive) async {
    if (friends.isEmpty) {
      Fluttertoast.showToast(msg: "No friends in ledger to export");
      return;
    }

    final userProvider = context.read<UserProvider>();
    final userName = userProvider.name.isNotEmpty ? userProvider.name : "User";

    Fluttertoast.showToast(msg: "Generating Friends PDF Summary...");
    await ExportService.exportAllFriendsPdf(
      userName: userName,
      friends: friends,
      totalGet: totalGet,
      totalGive: totalGive,
    );
  }

  String formatIndianNumber(int number) {
    return NumberFormat('#,##,##0', 'en_IN').format(number);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF8BC24A);

    return Consumer<FriendProvider>(
      builder: (context, friendProvider, _) {
        final allFriends = friendProvider.friends;
        final displayedFriends = searchQuery.trim().isEmpty
            ? allFriends
            : allFriends.where((friend) {
                final name = (friend["friend_name"] ?? "").toString().toLowerCase();
                final number = (friend["friend_number"] ?? "").toString();
                final query = searchQuery.toLowerCase();
                return name.contains(query) || number.contains(query);
              }).toList();

        final totalGet = friendProvider.totalGet;
        final totalGive = friendProvider.totalGive;
        final isLoading = friendProvider.isLoading;

        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 245, 245, 245),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: primaryColor,
            title: const Text(
              "Friend Ledger",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              IconButton(
                tooltip: "Export PDF Summary",
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: () => exportAllFriendsToPdf(allFriends, totalGet, totalGive),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            color: primaryColor,
            onRefresh: () => _loadFriends(force: true),
            child: Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "You Will Get",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                totalGet.toINR(compactSymbol: true),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 45, width: 1, color: Colors.white30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "You Will Give",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                totalGive.toINR(compactSymbol: true),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: TextField(
                    controller: searchController,
                    onChanged: (val) {
                      setState(() {
                        searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search friend...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = "";
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Friends Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      const Text(
                        "Friends",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SplitBillPage()),
                          );
                        },
                        icon: const Icon(Icons.call_split_rounded, size: 17),
                        label: const Text("Split Bill"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddFriends()),
                          );
                        },
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text("Add"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Friend List
                Expanded(
                  child: (isLoading && allFriends.isEmpty)
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                      : (friendProvider.hasError && allFriends.isEmpty)
                          ? ErrorRetryWidget(
                              message: friendProvider.errorMessage,
                              primaryColor: primaryColor,
                              onRetry: () => _loadFriends(force: true),
                            )
                          : (displayedFriends.isNotEmpty)
                              ? ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              itemCount: displayedFriends.length,
                              itemBuilder: (context, index) {
                                final friend = displayedFriends[index];
                                final friendName = (friend["friend_name"] ?? "Friend").toString();
                                final friendNumber = (friend["friend_number"] ?? "").toString();
                                final fGet = (double.tryParse(friend["total_get"]?.toString() ?? '0') ?? 0.0).round();
                                final fGive = (double.tryParse(friend["total_give"]?.toString() ?? '0') ?? 0.0).round();

                                return InkWell(
                                  onLongPress: () async {
                                    final friendProvider = context.read<FriendProvider>();
                                    final confirmed = await showDeleteConfirmDialog(
                                      context,
                                      title: "Delete Friend",
                                      message: "Are you sure you want to remove $friendName from ledger?",
                                    );
                                    if (confirmed == true) {
                                      final phone = await SessionManager.getPhoneNumber() ?? "";
                                      if (phone.isNotEmpty) {
                                        await friendProvider.deleteFriend(
                                          userPhone: phone,
                                          friendNumber: friendNumber,
                                        );
                                        Fluttertoast.showToast(msg: "Friend removed");
                                      }
                                    }
                                  },
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Specificfriendpage(
                                          friendNumber: friendNumber,
                                          friendName: friendName,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: .04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: primaryColor.withValues(alpha: .15),
                                          child: Text(
                                            friendName.isNotEmpty ? friendName[0].toUpperCase() : "F",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Name & Number
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                friendName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                friendNumber,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Get & Give
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: .10),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                "Get ${fGet.toINR(compactSymbol: true)}",
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(alpha: .10),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                "Give ${fGive.toINR(compactSymbol: true)}",
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
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
                            )
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                padding: const EdgeInsets.only(top: 80),
                                alignment: Alignment.center,
                                child: Text(
                                  searchQuery.isNotEmpty
                                      ? "No friends matching '$searchQuery'"
                                      : "No Friends Added Yet",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
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
}
