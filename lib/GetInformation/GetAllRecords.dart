import 'package:firebase_database/firebase_database.dart';

Future<List<Map<String, dynamic>>?> allRecords(
  String phone_number,
  String Specific,
) async {
  DatabaseReference myref = FirebaseDatabase.instance.ref(
    "Expenses/$phone_number",
  );
  DatabaseEvent event = await myref.once();
  List<Map<String, dynamic>> result = [];
  if (event.snapshot.value != null) {
    Map Data = event.snapshot.value as Map;

    if (["Spent Cash", "Spent Online", "Spent Cash For ADA", "Spent Online For ADA", "Add CASH", "Add Online"].contains(Specific)) {
      Data.forEach((key, value) {
        if (value["Payment_Mode"] == Specific) {
          result.add(Map<String, dynamic>.from(value));
        }
      });
    } else if (Specific == "All") {
      Data.forEach((key, value) {
        result.add(Map<String, dynamic>.from(value));
      });
    }
    if(result.isEmpty){
      return null;
    }
    result.sort((a,b) => 
      (b["timestamp"] as int).compareTo(a["timestamp"] as int)
    );
    return result;
  }
  return null;
}
