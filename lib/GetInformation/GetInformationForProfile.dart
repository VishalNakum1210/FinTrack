import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<List<String>> getProfieInformation(String phone_number) async {
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref(
      "Expenses/$phone_number",
    );
    DatabaseEvent event = await myref.once();
    int Expenses = 0;
    int count = 0;
    if (event.snapshot.value != null) {
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        if (!(["Add CASH", "Add Online"].contains(value["Payment_Mode"]))){
          count += 1;
          Expenses += int.parse(value["Amount"]);
        }
      });
      return[Expenses.toString(), count.toString()];
    }
  } catch (e) {
    Fluttertoast.showToast(msg: "Not connected $e");
  }
  return ["0", "0"];
}
