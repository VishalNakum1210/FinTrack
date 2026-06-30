import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PassbookApp extends StatefulWidget {
  @override
  State<PassbookApp> createState() => PassbookPage();
}

class PassbookPage extends State<PassbookApp> {
  int income = 0;
  int expense = 0;
  String selectSort = "Newest First";
  int recordCount = 0;
  List<String> sortList = ["Newest First", "Last First"];

  String balance = "*,**,***";

  static const Color green = Color(0xFF8BC24A);
  static const Color darkGreen = Color(0xFF8BC24A);

  void ShowHideBalance() {
    setState(() {
      balance = balance != "*,**,***" ? "*,**,***" : (income - expense).toString();
    });
  }

  Future<void> getDetails () async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String phone = sp.getString("phone_number")!;
    DatabaseReference myref = FirebaseDatabase.instance.ref("Expenses/$phone");

    DatabaseEvent event = await myref.once();

    if(event.snapshot.value != null){
      Map data = event.snapshot.value as Map;

      data.forEach(((key, value) {
        recordCount ++;
        if(["Add CASH", "Add Online"].contains(value["Payment_Mode"])){
          income += int.parse(value["Amount"]);
        }
        else{
          expense += int.parse(value["Amount"]);
        }
      }));
    }

    setState(() {

    });
  }

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,

        title: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                "assets/image/AccountApplicationLogo.jpg",
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PassBook Page",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

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
            const SizedBox(height: 10),
            _categoryChips(),
            const SizedBox(height: 10),
            _balanceCard(),
            const SizedBox(height: 10),
            _sortRow(),
            const SizedBox(height: 10),
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
                Icon(Icons.search, color: Colors.grey, size: 20),
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
          Icon(icon, color: iconColor, size: 15),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8BC24A), Color(0xFF689F38), Color(0xFF33691E)],
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
                    margin: EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: InkWell(
                      onTap: () {
                        ShowHideBalance();
                        },
                      child: Icon(
                        Icons.visibility_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Container(
                margin: EdgeInsets.only(left: 10),
                child: Text(
                  "₹ ${balance}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Container(
                margin: EdgeInsets.only(left: 10),
                child: Text(
                  "Updated just now",
                  style: TextStyle(
                    color: Colors.white.withOpacity(.75),
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Divider(color: Colors.white.withOpacity(.20), thickness: 1),

              const SizedBox(height: 10),

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
                      recordCount,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              DropdownMenu<String>(
                initialSelection: selectSort,
                dropdownMenuEntries: sortList
                    .map((item) => DropdownMenuEntry(value: item, label: item))
                    .toList(),

                onSelected: (value) {
                  setState(() {
                    selectSort = value!;
                  });
                },

                inputDecorationTheme: InputDecorationTheme(
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      width: 3,
                      color: Color(0xFFE0E0E0),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      width: 3,
                      color: Color(0xFFE0E0E0),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          Text(
            date,
            style: const TextStyle(
              fontSize: 15,
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
                        '$method',
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
