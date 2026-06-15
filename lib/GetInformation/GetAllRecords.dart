import 'package:firebase_database/firebase_database.dart';

Future<List<Map<String, dynamic>>?> allRecords (String phone_number, String Specific) async {
  DatabaseReference myref = FirebaseDatabase.instance.ref("Expenses/$phone_number");
  DatabaseEvent event = await myref.once();
  List<Map<String, dynamic>> result = [];
  if(event.snapshot.value != null){
    Map Data = event.snapshot.value as Map;

    Data.forEach((key, value) {
      result.add(Map<String, dynamic>.from(value));
    });
    print(result);
    return result;
  }
  return null;
} 