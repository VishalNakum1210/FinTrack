import 'package:firebase_database/firebase_database.dart';

Future<List<String>> getTotalFriendExpenses(String phoneNumber) async {
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref("Friends/$phoneNumber");
    DatabaseEvent event = await myref.once();

    if (event.snapshot.value != null) {
      int totalGet = 0;
      int totalGive = 0;
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        if (value is Map) {
          totalGet += int.tryParse(value["total_get"]?.toString() ?? '0') ?? 0;
          totalGive += int.tryParse(value["total_give"]?.toString() ?? '0') ?? 0;
        }
      });
      return [totalGet.toString(), totalGive.toString()];
    }
  } catch (_) {
    // Return safe default
  }
  return ["0", "0"];
}