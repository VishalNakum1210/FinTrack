import 'package:flutter/material.dart';

class PassbookApp extends StatelessWidget {
  const PassbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: PassbookPage(),
    );
  }
}

class PassbookPage extends StatelessWidget {
  PassbookPage({super.key});

  int income = 35000;
  int expense = 18500;

  int get balance => income - expense;

  static const Color green = Color(0xFF138A3D);
  static const Color darkGreen = Color(0xFF006B45);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: green,
        shape: const CircleBorder(),
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white, size: 34),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchRow(),
            const SizedBox(height: 18),
            _categoryChips(),
            const SizedBox(height: 20),
            _balanceCard(),
            const SizedBox(height: 20),
            _sortRow(),
            const SizedBox(height: 18),
            _sectionHeader('Today', '25 June 2026'),
            _transactionTile(
              icon: Icons.fastfood,
              iconColor: Colors.orange,
              bgColor: const Color(0xFFFFF1D8),
              title: 'Food',
              subtitle: "Domino's Pizza",
              method: 'Cash',
              time: '7:45 PM',
              amount: '- ₹250',
              isIncome: false,
            ),
            _transactionTile(
              icon: Icons.directions_car,
              iconColor: Colors.blue,
              bgColor: const Color(0xFFE2F4FF),
              title: 'Transport',
              subtitle: 'Auto Rickshaw',
              method: 'UPI',
              time: '2:30 PM',
              amount: '- ₹120',
              isIncome: false,
            ),
            const SizedBox(height: 18),
            _sectionHeader('Yesterday', '24 June 2026'),
            _transactionTile(
              icon: Icons.savings,
              iconColor: green,
              bgColor: const Color(0xFFE7F7DD),
              title: 'Salary',
              subtitle: 'Monthly Salary',
              method: 'Bank Transfer',
              time: '9:00 AM',
              amount: '+ ₹35,000',
              isIncome: true,
            ),
            _transactionTile(
              icon: Icons.shopping_bag,
              iconColor: Colors.pink,
              bgColor: const Color(0xFFFFE1EB),
              title: 'Shopping',
              subtitle: 'Shoes',
              method: 'Credit Card',
              time: '8:10 PM',
              amount: '- ₹800',
              isIncome: false,
            ),
            const SizedBox(height: 18),
            _sectionHeader('22 June 2026', '22 June 2026'),
            _transactionTile(
              icon: Icons.medical_services,
              iconColor: Colors.purple,
              bgColor: const Color(0xFFF0E2FF),
              title: 'Healthcare',
              subtitle: 'Medicine',
              method: 'Cash',
              time: '6:20 PM',
              amount: '- ₹450',
              isIncome: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.grey, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search category or description...',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: const Icon(Icons.tune, size: 28),
        ),
      ],
    );
  }

  Widget _categoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(Icons.grid_view_rounded, 'All', true, green),
          _chip(Icons.arrow_downward, 'Expense', false, Colors.red),
          _chip(Icons.arrow_upward, 'Income', false, Colors.green),
          _chip(Icons.fastfood, 'Food', false, Colors.orange),
          _chip(Icons.shopping_bag, 'Shopping', false, Colors.deepOrange),
          _chip(Icons.more_horiz, 'More', false, Colors.black87),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, bool selected, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF2FFF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? green : const Color(0xFFE8E8E8),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff34D399), Color(0xff16A34A), Color(0xff166534)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -35,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            left: -30,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 15),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Balance",
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),

                        SizedBox(height: 4),

                        Text(
                          "Available Balance",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                "₹ ${balance}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "Updated just now",
                style: TextStyle(
                  color: Colors.white.withOpacity(.75),
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 28),

              Divider(color: Colors.white.withOpacity(.20), thickness: 1),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: balanceItem(
                      Icons.arrow_upward_rounded,
                      Colors.greenAccent,
                      "Income",
                      income,
                    ),
                  ),

                  Container(height: 45, width: 1, color: Colors.white24),

                  Expanded(
                    child: balanceItem(
                      Icons.arrow_downward_rounded,
                      Colors.redAccent.shade100,
                      "Expense",
                      expense,
                    ),
                  ),

                  Container(height: 45, width: 1, color: Colors.white24),

                  Expanded(
                    child: balanceItem(
                      Icons.receipt_long_rounded,
                      Colors.white,
                      "Records",
                      "24",
                      isMoney: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortRow() {
    return Row(
      children: [
        const Text(
          'Sort by:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Text('Newest First', style: TextStyle(fontSize: 16)),
              SizedBox(width: 10),
              Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            date,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String method,
    required String time,
    required String amount,
    required bool isIncome,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      method == 'Cash'
                          ? Icons.account_balance_wallet
                          : method == 'UPI'
                          ? Icons.mobile_friendly
                          : method == 'Bank Transfer'
                          ? Icons.account_balance
                          : Icons.credit_card,
                      color: Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$method  •  $time',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              color: isIncome ? green : Colors.red.shade700,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.more_vert, color: Colors.grey),
        ],
      ),
    );
  }
}

class _BalanceInfo extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color iconColor;

  const _BalanceInfo({
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalLine extends StatelessWidget {
  const _VerticalLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 1,
      color: Colors.white.withOpacity(0.25),
    );
  }
}

Widget balanceItem(
  IconData icon,
  Color iconColor,
  String title,
  dynamic value, {
  bool isMoney = true,
}) {
  return Column(
    children: [
      Icon(icon, color: iconColor, size: 22),

      const SizedBox(height: 10),

      Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      const SizedBox(height: 6),

      Text(
        isMoney ? "₹${value}" : value.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
