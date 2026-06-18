import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<List<String>> getTotalFriendExpenses (String phone_number) async {
  try{
    DatabaseReference myref = FirebaseDatabase.instance.ref("Friends/$phone_number");
    DatabaseEvent event = await myref.once();

    if(event.snapshot.value != null){
      int total_get = 0, total_give = 0;
      Map data = event.snapshot.value as Map;

      data.forEach((key, value) {
        total_get += int.parse(value["total_give"]);
        total_give += int.parse(value["total_take"]);
      });

      print("$total_get  $total_give");
      return[total_get.toString(), total_give.toString()];
    }else{
      return ["0", "0"];
    }
  }catch (e) {
    Fluttertoast.showToast(msg: "Not connected : $e");
  }
  return ["0","0"];
}