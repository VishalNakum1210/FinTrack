import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<List<Map<String, dynamic>>?> getFriendDetails (String phone_number) async{
  try{
    DatabaseReference myref = FirebaseDatabase.instance.ref("Friends/$phone_number");
    DatabaseEvent event = await myref.once();
    List<Map<String, dynamic>> result = [];
    if(event.snapshot.value != null){
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        result.add(Map<String, dynamic>.from(value));
      });
      print(result);
      return result;
    }
    return null;
  }catch(e){
    Fluttertoast.showToast(msg: "Not connected $e");
  }
}