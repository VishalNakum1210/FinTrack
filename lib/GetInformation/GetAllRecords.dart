import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

Future<List<Map<String, dynamic>>> allRecords(
  String phoneNumber,
  String specific,
) async {
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref(
      "Expenses/$phoneNumber",
    );
    DatabaseEvent event = await myref.once();
    List<Map<String, dynamic>> result = [];
    if (event.snapshot.value != null) {
      Map data = event.snapshot.value as Map;
      const categories = [
        "Food",
        "Shopping",
        "Transport",
        "Education",
        "HealthCare",
        "Entertainment",
        "Add Money",
        "Other",
      ];
      const paymentModes = [
        "Spent Cash",
        "Spent Online",
        "Spent Cash For ADA",
        "Spent Online For ADA",
        "Add CASH",
        "Add Online",
      ];

      data.forEach((key, value) {
        if (value is Map) {
          Map<String, dynamic> item = Map<String, dynamic>.from(value);
          if (specific == "All") {
            result.add(item);
          } else if (categories.contains(specific)) {
            if (item["Category"] == specific) {
              result.add(item);
            }
          } else if (paymentModes.contains(specific)) {
            if (item["Payment_Mode"] == specific) {
              result.add(item);
            }
          } else {
            if (item["Category"] == specific || item["Payment_Mode"] == specific) {
              result.add(item);
            }
          }
        }
      });

      if (result.isEmpty) {
        return [];
      }

      final formatter = DateFormat("d/M/yyyy");

      result.sort((a, b) {
        if (a["timestamp"] != null && b["timestamp"] != null) {
          return (a["timestamp"] as num).compareTo(b["timestamp"] as num);
        }
        try {
          String dateStrA = (a["Date"] ?? "").toString();
          String dateStrB = (b["Date"] ?? "").toString();
          DateTime dateA = formatter.parse(dateStrA);
          DateTime dateB = formatter.parse(dateStrB);
          return dateA.compareTo(dateB);
        } catch (_) {
          return 0;
        }
      });
      return result;
    }
  } catch (e) {
    // Return empty list on error
  }
  return [];
}
