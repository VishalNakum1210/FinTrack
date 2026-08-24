import 'package:firebase_database/firebase_database.dart';

Future<String> getTotalExpenses(String phoneNumber, String specific) async {
  int count = 0;
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref(
      "Expenses/$phoneNumber",
    );
    DatabaseEvent event = await myref.once();

    if (event.snapshot.value != null) {
      Map value = event.snapshot.value as Map;

      value.forEach((key, data) {
        if (data is Map) {
          String paymentMode = (data["Payment_Mode"] ?? "").toString();
          String category = (data["Category"] ?? "").toString();
          int amount = int.tryParse(data["Amount"]?.toString() ?? '0') ?? 0;

          if (specific == "All") {
            if (!["Add CASH", "Add Online"].contains(paymentMode)) {
              count += amount;
            }
          } else if (paymentMode == specific || category == specific) {
            count += amount;
          }
        }
      });
    }
  } catch (_) {
    // Return safe default
  }
  return count.toString();
}
