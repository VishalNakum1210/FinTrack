import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<List<Map<String, dynamic>>> getSpecificFriendDetails(
  String phone_number,
  String Friend_phone_number,
) async {
  List<Map<String, dynamic>> result = [];
  try {
    DatabaseReference myref = FirebaseDatabase.instance.ref(
      "Friends/$phone_number",
    );
    DatabaseEvent event = await myref.once();
    if (event.snapshot.value != null) {
      Map data = event.snapshot.value as Map;
      data.forEach((Key, value) {
        if (Key == Friend_phone_number) {
          result.add(Map<String, dynamic>.from(value));
        }
      });
    } else {
      Fluttertoast.showToast(msg: "Friend Not Found");
    }
  } catch (e) {
    Fluttertoast.showToast(msg: "$e");
    print(e);
  }
  return result;
}
