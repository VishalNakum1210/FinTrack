import 'package:firebase_database/firebase_database.dart';

Future<Map<String, String>> getUserInformation(String phoneNumber) async {
  Map<String, String> result = {};
  if (phoneNumber.length != 10 || int.tryParse(phoneNumber) == null) {
    return result;
  }
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref("user_details/$phoneNumber");
    DatabaseEvent event = await myref.once().timeout(const Duration(seconds: 8));

    if (event.snapshot.value != null && event.snapshot.value is Map) {
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        final keyStr = key.toString();
        final valStr = (value ?? "").toString();
        result[keyStr] = valStr;
        final lowerKey = keyStr.toLowerCase();
        if (!result.containsKey(lowerKey)) {
          result[lowerKey] = valStr;
        }
      });
    }
  } catch (_) {}
  return result;
}
