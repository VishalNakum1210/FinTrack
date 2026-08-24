import 'package:FinTrack/FriendsPages/addFriends.dart';
import 'package:FinTrack/FriendsPages/specificFriendPage.dart';
import 'package:FinTrack/GetInformation/SessionManager.dart';
import 'package:FinTrack/providers/friend_provider.dart';
import 'package:flutter/material.dart';
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

  Future<void> _loadFriends() async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (mounted && phone.isNotEmpty) {
      context.read<FriendProvider>().fetchFriends(phone);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
          ),
          body: RefreshIndicator(
            color: primaryColor,
            onRefresh: _loadFriends,
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
                            Text(
                              NumberFormat.currency(
                                locale: 'en_IN',
                                symbol: '₹',
                                decimalDigits: 0,
                              ).format(totalGet),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
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
                            Text(
                              NumberFormat.currency(
                                locale: 'en_IN',
                                symbol: '₹',
                                decimalDigits: 0,
                              ).format(totalGive),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
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
                  child: (isLoading)
                      ? Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                      : (displayedFriends.isNotEmpty)
                          ? ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              itemCount: displayedFriends.length,
                              itemBuilder: (context, index) {
                                final friend = displayedFriends[index];
                                final friendName = (friend["friend_name"] ?? "Friend").toString();
                                final friendNumber = (friend["friend_number"] ?? "").toString();
                                final fGet = int.tryParse(friend["total_get"]?.toString() ?? '0') ?? 0;
                                final fGive = int.tryParse(friend["total_give"]?.toString() ?? '0') ?? 0;

                                return InkWell(
                                  onLongPress: () async {
                                    showDialog(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: const Text("Delete Friend"),
                                        content: Text(
                                          "Are you sure you want to remove $friendName from ledger?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(dialogCtx);
                                              final phone = await SessionManager.getPhoneNumber() ?? "";
                                              if (phone.isNotEmpty && context.mounted) {
                                                await context.read<FriendProvider>().deleteFriend(
                                                  userPhone: phone,
                                                  friendNumber: friendNumber,
                                                );
                                              }
                                            },
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Specificfriendpage(
                                          friend_number: friendNumber,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
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
                                        // Avatar
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: primaryColor.withValues(alpha: .15),
                                          child: Text(
                                            friendName.isNotEmpty
                                                ? friendName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Name & Number
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                friendName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
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
                                                NumberFormat.currency(
                                                  locale: 'en_IN',
                                                  symbol: 'Get ₹',
                                                  decimalDigits: 0,
                                                ).format(fGet),
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
                                                NumberFormat.currency(
                                                  locale: 'en_IN',
                                                  symbol: 'Give ₹',
                                                  decimalDigits: 0,
                                                ).format(fGive),
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
                          : Center(
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
              ],
            ),
          ),
        );
      },
    );
  }
}
