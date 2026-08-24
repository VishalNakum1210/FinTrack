import 'package:firebase_database/firebase_database.dart';

Future<List<String>> getAllInformation(String phoneNumber) async {
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref("Expenses/$phoneNumber");
    DatabaseEvent event = await myref.once();

    int addCash = 0;
    int totalCashExpenses = 0;
    int addOnline = 0;
    int totalOnlineExpenses = 0;

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> data = event.snapshot.value as Map;

      data.forEach((key, value) {
        if (value is Map) {
          String mode = (value["Payment_Mode"] ?? "").toString();
          int amount = int.tryParse(value['Amount']?.toString() ?? '0') ?? 0;
          if (mode == "Add CASH") {
            addCash += amount;
          } else if (mode == "Spent Cash" || mode == "Spent Cash For ADA") {
            totalCashExpenses += amount;
          } else if (mode == "Add Online") {
            addOnline += amount;
          } else if (mode == "Spent Online" || mode == "Spent Online For ADA") {
            totalOnlineExpenses += amount;
          } else {
            totalOnlineExpenses += amount;
          }
        }
      });

      return [
        totalCashExpenses.toString(),
        addCash.toString(),
        totalOnlineExpenses.toString(),
        addOnline.toString(),
      ];
    }
  } catch (_) {
    // Return default values on error
  }
  return ["0", "0", "0", "0"];
}