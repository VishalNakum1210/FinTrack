import 'package:firebase_database/firebase_database.dart';

Future<String> getTotalExpenses (String phone_number) async {
  int count = 0;
  Map<dynamic, dynamic> value = {};

  DatabaseReference myref = FirebaseDatabase.instance.ref("Expenses/$phone_number");
  DatabaseEvent event = await myref.once();

  if(event.snapshot.value != null){
    value = event.snapshot.value as Map;
    value.forEach((key, data) {
      count += int.tryParse(data["Amount"].toString()) ?? 0;
    });
    print(count);
  }
  return count.toString();
}