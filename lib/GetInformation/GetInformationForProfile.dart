import 'package:firebase_database/firebase_database.dart';

Future<List<String>> getProfieInformation(String phoneNumber) async {
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref(
      "Expenses/$phoneNumber",
    );
    DatabaseEvent event = await myref.once();
    int expenses = 0;
    int count = 0;
    if (event.snapshot.value != null) {
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        if (value is Map) {
          String paymentMode = (value["Payment_Mode"] ?? "").toString();
          if (!["Add CASH", "Add Online"].contains(paymentMode)) {
            count += 1;
            expenses += int.tryParse(value["Amount"]?.toString() ?? '0') ?? 0;
          }
        }
      });
      return [expenses.toString(), count.toString()];
    }
  } catch (_) {
    // Return safe default
  }
  return ["0", "0"];
}
