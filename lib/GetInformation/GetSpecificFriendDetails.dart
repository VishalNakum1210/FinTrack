import 'package:firebase_database/firebase_database.dart';

Future<List<Map<String, dynamic>>> getSpecificFriendDetails(
  String phoneNumber,
  String friendPhoneNumber,
) async {
  List<Map<String, dynamic>> result = [];
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref(
      "Friends/$phoneNumber/$friendPhoneNumber",
    );
    DatabaseEvent event = await myref.once();
    if (event.snapshot.value != null && event.snapshot.value is Map) {
      Map data = event.snapshot.value as Map;
      result.add(Map<String, dynamic>.from(data));
    }
  } catch (_) {
    // Return empty list on failure
  }
  return result;
}
