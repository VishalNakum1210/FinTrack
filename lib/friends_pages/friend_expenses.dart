import 'package:fin_track/friends_pages/add_friends.dart';
import 'package:fin_track/friends_pages/specific_friend_page.dart';
import 'package:fin_track/friends_pages/split_bill_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/widgets/confirm_dialog.dart';
import 'package:fin_track/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class FriendPage extends StatefulWidget {
  const FriendPage({super.key});

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  static const Color primaryGreen = CategoryTheme.primaryGreen;
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String sortBy = "Recent"; // 'Recent', 'Balance', 'Name'

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

  Future<void> exportAllFriendsToPdf(
    List<Map<String, dynamic>> friends,
    int totalGet,
    int totalGive,
  ) async {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, _) {
        final allFriends = friendProvider.friends;
        var displayedFriends = searchQuery.trim().isEmpty
            ? List<Map<String, dynamic>>.from(allFriends)
            : allFriends.where((friend) {
                final name = (friend["friend_name"] ?? "").toString().toLowerCase();
                final number = (friend["friend_number"] ?? "").toString();
                final query = searchQuery.toLowerCase();
                return name.contains(query) || number.contains(query);
              }).toList();

        if (sortBy == "Name") {
          displayedFriends.sort((a, b) => (a["friend_name"] ?? "")
              .toString()
              .toLowerCase()
              .compareTo((b["friend_name"] ?? "").toString().toLowerCase()));
        } else if (sortBy == "Balance") {
          displayedFriends.sort((a, b) {
            final balA = ((double.tryParse(a["total_get"]?.toString() ?? '0') ?? 0) -
                    (double.tryParse(a["total_give"]?.toString() ?? '0') ?? 0))
                .abs();
            final balB = ((double.tryParse(b["total_get"]?.toString() ?? '0') ?? 0) -
                    (double.tryParse(b["total_give"]?.toString() ?? '0') ?? 0))
                .abs();
            return balB.compareTo(balA);
          });
        }

        final totalGet = friendProvider.totalGet;
        final totalGive = friendProvider.totalGive;
        final netBalance = totalGet - totalGive;
        final isLoading = friendProvider.isLoading;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            titleSpacing: 16,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Friends & Split Ledger",
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  "Track group balances & settle up",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: "Export PDF Summary",
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: primaryGreen, size: 20),
                ),
                onPressed: () => exportAllFriendsToPdf(allFriends, totalGet, totalGive),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            color: primaryGreen,
            onRefresh: () => _loadFriends(force: true),
            child: (isLoading && allFriends.isEmpty)
                ? const Center(child: CircularProgressIndicator(color: primaryGreen))
                : (friendProvider.hasError && allFriends.isEmpty)
                    ? ErrorRetryWidget(
                        message: friendProvider.errorMessage,
                        primaryColor: primaryGreen,
                        onRetry: () => _loadFriends(force: true),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. OVERALL BALANCE HERO CARD
                            _buildOverallBalanceCard(
                              totalGet: totalGet,
                              totalGive: totalGive,
                              netBalance: netBalance,
                            ),
                            const SizedBox(height: 16),

                            // 2. QUICK ACTION DOCK (Add Friend + Split Bill)
                            _buildActionDock(),
                            const SizedBox(height: 16),

                            // 3. SEARCH DOCK
                            _buildSearchDock(),
                            const SizedBox(height: 12),

                            // 4. SORT PILLS ROW
                            _buildSortRow(displayedFriends.length),
                            const SizedBox(height: 14),

                            // 5. FRIENDS LIST
                            if (displayedFriends.isEmpty)
                              _buildEmptyState()
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayedFriends.length,
                                itemBuilder: (context, index) {
                                  final friend = displayedFriends[index];
                                  return _buildFriendCard(friend);
                                },
                              ),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  Widget _buildOverallBalanceCard({
    required int totalGet,
    required int totalGive,
    required int netBalance,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Net Ledger Position",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      netBalance >= 0 ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      netBalance >= 0 ? "You are owed" : "You owe",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              netBalance.abs().toINR(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // You Get Capsule
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "You Will Get",
                              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                totalGet.toINR(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
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
              ),
              const SizedBox(width: 10),

              // You Give Capsule
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "You Will Give",
                              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                totalGive.toINR(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionDock() {
    return Row(
      children: [
        // Add Friend Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddFriends()),
              );
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text("Add Friend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Split Bill Button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SplitBillPage()),
              );
            },
            icon: const Icon(Icons.call_split_rounded, size: 18, color: Color(0xFF7C3AED)),
            label: const Text(
              "Split Bill",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF7C3AED)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7C3AED), width: 1.4),
              backgroundColor: const Color(0xFFF5F3FF),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchDock() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (val) => setState(() => searchQuery = val),
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: "Search friend by name or phone...",
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchQuery = "");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSortRow(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "$count ${count == 1 ? 'friend' : 'friends'} in ledger",
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Row(
          children: [
            const Text("Sort: ", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            for (final s in ["Recent", "Balance", "Name"]) ...[
              GestureDetector(
                onTap: () => setState(() => sortBy = s),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sortBy == s ? primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sortBy == s ? primaryGreen : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: sortBy == s ? FontWeight.bold : FontWeight.w500,
                      color: sortBy == s ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final friendName = (friend["friend_name"] ?? "Friend").toString();
    final friendNumber = (friend["friend_number"] ?? "").toString();
    final fGet = (double.tryParse(friend["total_get"]?.toString() ?? '0') ?? 0.0).round();
    final fGive = (double.tryParse(friend["total_give"]?.toString() ?? '0') ?? 0.0).round();
    final net = fGet - fGive;

    final avatarColor = Colors.primaries[
        (friendName.isNotEmpty ? friendName.codeUnitAt(0) : 0) % Colors.primaries.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          onLongPress: () async {
            final confirmed = await showDeleteConfirmDialog(
              context,
              title: "Delete Friend",
              message: "Are you sure you want to remove $friendName from your ledger?",
            );
            if (confirmed == true) {
              final phone = await SessionManager.getPhoneNumber() ?? "";
              if (phone.isNotEmpty && mounted) {
                await context.read<FriendProvider>().deleteFriend(
                      userPhone: phone,
                      friendNumber: friendNumber,
                    );
                Fluttertoast.showToast(msg: "Friend removed from ledger");
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 23,
                  backgroundColor: avatarColor.withValues(alpha: .15),
                  child: Text(
                    friendName.isNotEmpty ? friendName[0].toUpperCase() : "F",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Friend Name & Mobile
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friendName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        friendNumber,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Net Balance Pill + Arrow
                Row(
                  children: [
                    if (net > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Gets ${net.toINR()}",
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else if (net < 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Owes ${net.abs().toINR()}",
                          style: const TextStyle(
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Settled ✓",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_outlined, size: 42, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Text(
            searchQuery.isNotEmpty ? "No friends matching '$searchQuery'" : "No Friends Added Yet",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap 'Add Friend' above to track loans, shared bills, and settlements.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
