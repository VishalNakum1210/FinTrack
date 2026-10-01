import 'package:fin_track/utils/money.dart';
import 'package:fin_track/friends_pages/add_friends.dart';
import 'package:fin_track/friends_pages/add_friend_spent.dart';
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
    double totalGet,
    double totalGive,
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

  void _showSettleModal(String friendName, String friendNumber, double net) {
    if (net == 0) {
      Fluttertoast.showToast(
        msg: "All settled up with $friendName! No outstanding balance.",
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final isOwed = net > 0;
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
                      "Settle with $friendName",
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
                        isOwed ? "Amount to Collect:" : "Amount to Pay:",
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddFriendExpenses(friendNumber: friendNumber),
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
                          ? "Record Received Settlement"
                          : "Record Payment Made",
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
    return Consumer<FriendProvider>(
      builder: (context, friendProvider, _) {
        final allFriends = friendProvider.friends;
        var displayedFriends = searchQuery.trim().isEmpty
            ? List<Map<String, dynamic>>.from(allFriends)
            : allFriends.where((friend) {
                final name = (friend["friend_name"] ?? "")
                    .toString()
                    .toLowerCase();
                final number = (friend["friend_number"] ?? "").toString();
                final query = searchQuery.toLowerCase();
                return name.contains(query) || number.contains(query);
              }).toList();

        if (sortBy == "Name") {
          displayedFriends.sort(
            (a, b) => (a["friend_name"] ?? "")
                .toString()
                .toLowerCase()
                .compareTo((b["friend_name"] ?? "").toString().toLowerCase()),
          );
        } else if (sortBy == "Balance") {
          displayedFriends.sort((a, b) {
            final balA =
                ((double.tryParse(a["total_get"]?.toString() ?? '0') ?? 0) -
                        (double.tryParse(a["total_give"]?.toString() ?? '0') ??
                            0))
                    .abs();
            final balB =
                ((double.tryParse(b["total_get"]?.toString() ?? '0') ?? 0) -
                        (double.tryParse(b["total_give"]?.toString() ?? '0') ??
                            0))
                    .abs();
            return balB.compareTo(balA);
          });
        }

        final totalGet = friendProvider.totalGet;
        final totalGive = friendProvider.totalGive;
        final isLoading = friendProvider.isLoading;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: primaryGreen,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            titleSpacing: 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Friends & Split Ledger",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  "${allFriends.length} ${allFriends.length == 1 ? 'Friend' : 'Friends'}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: "Export PDF Summary",
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
                onPressed: () =>
                    exportAllFriendsToPdf(allFriends, totalGet, totalGive),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            color: primaryGreen,
            onRefresh: () => _loadFriends(force: true),
            child: (isLoading && allFriends.isEmpty)
                ? const Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  )
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
                        // 1. SEARCH BAR + ADD FRIEND BUTTON
                        _buildSearchAndAddBar(),
                        const SizedBox(height: 16),

                        // 2. OVERALL BALANCE BANNER (You Get vs You Owe)
                        _buildOverallBalanceBanner(
                          totalGet: totalGet,
                          totalGive: totalGive,
                        ),
                        const SizedBox(height: 16),

                        // 3. SORT PILLS & SPLIT BILL QUICK ACTION ROW
                        _buildSortAndActionRow(displayedFriends.length),
                        const SizedBox(height: 14),

                        // 4. FRIENDS LIST
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

  Widget _buildSearchAndAddBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = "");
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) => setState(() => searchQuery = val.trim()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddFriends()),
              );
              if (res == true) _loadFriends(force: true);
            },
            icon: const Icon(Icons.add, color: primaryGreen, size: 18),
            label: const Text(
              "Add Friend",
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryGreen, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallBalanceBanner({
    required double totalGet,
    required double totalGive,
  }) {
    return Row(
      children: [
        // Total You Get Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total You Get:",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    totalGet.toINR(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Total You Owe Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total You Owe:",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    totalGive.toINR(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC62828),
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

  Widget _buildSortAndActionRow(int count) {
    final sorts = ["Recent", "Balance", "Name"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in sorts) ...[
                  GestureDetector(
                    onTap: () => setState(() => sortBy = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: sortBy == s ? primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sortBy == s
                              ? primaryGreen
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: sortBy == s
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: sortBy == s
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SplitBillPage()),
          ),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.call_split_rounded,
                  size: 14,
                  color: Color(0xFF6D28D9),
                ),
                SizedBox(width: 4),
                Text(
                  "Split Bill",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final friendName = (friend["friend_name"] ?? "Friend").toString();
    final friendNumber = (friend["friend_number"] ?? "").toString();
    final fGet = Money.rupees(friend["total_get"]);
    final fGive = Money.rupees(friend["total_give"]);
    final net = fGet - fGive;
    final initials = _getInitials(friendName);

    Color pillBg;
    Color pillTextColor;
    String pillText;

    if (net > 0) {
      pillBg = const Color(0xFFE8F5E9);
      pillTextColor = const Color(0xFF2E7D32);
      pillText = "You will get ${net.toINR()}";
    } else if (net < 0) {
      pillBg = const Color(0xFFFFEBEE);
      pillTextColor = const Color(0xFFC62828);
      pillText = "You owe ${net.abs().toINR()}";
    } else {
      pillBg = const Color(0xFFF1F5F9);
      pillTextColor = const Color(0xFF64748B);
      pillText = "All settled up";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              message:
                  "Are you sure you want to remove $friendName from your ledger?",
            );
            if (confirmed == true) {
              final phone = await SessionManager.getPhoneNumber() ?? "";
              if (phone.isNotEmpty && mounted) {
                final provider = context.read<FriendProvider>();
                final removed = await provider.deleteFriend(
                  userPhone: phone,
                  friendNumber: friendNumber,
                );
                Fluttertoast.showToast(
                  msg: removed
                      ? "Friend removed from ledger"
                      : provider.lastError ??
                            'Unable to delete friend. Please retry.',
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top Row: Circular Avatar with Initials + Friend Name & Phone
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friendName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bottom Row: Status Pill + Settle Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Pill
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pillText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: pillTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Settle Button
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () =>
                            _showSettleModal(friendName, friendNumber, net),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: const BorderSide(
                            color: primaryGreen,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text(
                          "Settle",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8BC24A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              size: 40,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty
                ? "No friends found matching \"$searchQuery\""
                : "No friends added yet",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            "Add friends to record shared expenses and split bills easily.",
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddFriends()),
              );
              if (res == true) _loadFriends(force: true);
            },
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text(
              "Add First Friend",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
