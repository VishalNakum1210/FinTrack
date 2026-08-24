import 'package:firebase_database/firebase_database.dart';

Future<Map<String, String>> getUserInformation(String phoneNumber) async {
  Map<String, String> result = {};
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref("user_details/$phoneNumber");
    DatabaseEvent event = await myref.once();

    if (event.snapshot.value != null && event.snapshot.value is Map) {
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        result[key.toString()] = (value ?? "").toString();
      });
    }
  } catch (_) {
    // Return empty map on error
  }
  return result;
}