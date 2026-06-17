import 'package:firebase_database/firebase_database.dart';

Future<String> getTotalExpenses(String phone_number, String Specific) async {
  int count = 0;
  Map<dynamic, dynamic> value = {};

  DatabaseReference myref = FirebaseDatabase.instance.ref(
    "Expenses/$phone_number",
  );
  DatabaseEvent event = await myref.once();

  if (event.snapshot.value != null) {
    value = event.snapshot.value as Map;

    if ([
      "All",
      "Spent Cash",
      "Spent Online",
      "Spent Cash For ADA",
      "Spent Online For ADA",
      "Add CASH",
      "Add Online"
    ].contains(Specific)) {
      value.forEach((key, data) {
        if ((Specific == "All" && !["Add CASH", "Add Online"].contains(data["Payment_Mode"])) || data["Payment_Mode"] == Specific) {
          count += int.parse(data["Amount"].toString());
        }
      });
    }
  }
  return count.toString();
}
