import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<Map<String, String>> getUserInformation (String phone_number) async {
  Map<String, String> result = {};
  try{
    DatabaseReference myref = FirebaseDatabase.instance.ref("user_details/$phone_number");
    DatabaseEvent event = await myref.once();

    if(event.snapshot.value != null){
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        result[key] = value;
      });
    }
  }catch(e){
    Fluttertoast.showToast(msg: "Not Connected $e");
  }
  return result;
}