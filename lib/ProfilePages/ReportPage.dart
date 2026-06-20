import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Reports",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [

            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff16A34A),
                    Color(0xff22C55E),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Balance",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "₹12,540",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        "+18% this month",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Income Expense
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.arrow_downward,
                    color: Colors.green,
                    title: "Income",
                    amount: "₹25,000",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.arrow_upward,
                    color: Colors.red,
                    title: "Expense",
                    amount: "₹12,460",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Insights
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Quick Insights",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: const [
                InsightCard(
                  icon: Icons.local_fire_department,
                  title: "Biggest Expense",
                  value: "Shopping",
                ),
                InsightCard(
                  icon: Icons.monetization_on,
                  title: "Highest Income",
                  value: "₹5,000",
                ),
                InsightCard(
                  icon: Icons.receipt_long,
                  title: "Transactions",
                  value: "124",
                ),
                InsightCard(
                  icon: Icons.calendar_month,
                  title: "Active Days",
                  value: "22",
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Categories
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Top Categories",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 15),

            categoryTile(
              icon: Icons.shopping_bag,
              title: "Shopping",
              amount: "₹4,500",
              value: 0.8,
            ),

            categoryTile(
              icon: Icons.fastfood,
              title: "Food",
              amount: "₹2,200",
              value: 0.5,
            ),

            categoryTile(
              icon: Icons.sports_esports,
              title: "Entertainment",
              amount: "₹1,200",
              value: 0.3,
            ),

            const SizedBox(height: 20),

            // Friend Summary
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: Colors.green,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Friend Summary",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Given"),
                      Text(
                        "₹1,700",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Taken"),
                      Text(
                        "₹200",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Health Score
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.green.shade50,
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.green,
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Financial Health",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text("Excellent"),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget categoryTile({
    required IconData icon,
    required String title,
    required String amount,
    required double value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: value,
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          )
        ],
      ),
    );
  }

  static Widget _statCard({
    required IconData icon,
    required Color color,
    required String title,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(title),
          const SizedBox(height: 5),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const InsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
        children: [
          Icon(icon, color: Colors.green),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}