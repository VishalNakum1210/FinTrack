import 'package:firebase_database/firebase_database.dart';

Future<List<String>> getAllInformation (String phone_number) async {
  DatabaseReference myref = FirebaseDatabase.instance.ref("Expenses/$phone_number");
  DatabaseEvent event = await myref.once();

  int Add_CASH = 0, totalCashExpenses = 0, Add_online = 0, totalOnlineExpenses = 0;

  if(event.snapshot.value != null){
    Map<dynamic, dynamic> data = event.snapshot.value as Map;

    data.forEach((key, value) {
      String Mode = value["Payment_Mode"];
      int Amount = int.parse(value['Amount']);
      if(Mode == "Add CASH"){
        print(value["Amount"]);
        Add_CASH += Amount;
      }
      else if (Mode == "Spent Cash" || Mode == "Spent Cash For ADA") {
        totalCashExpenses += Amount;
      }
      else if (Mode == "Add Online"){
        Add_online += Amount;
      }
      else{
        totalOnlineExpenses += Amount;
      }
    });

    return[totalCashExpenses.toString(), Add_CASH.toString(), totalOnlineExpenses.toString(),  Add_online.toString()];
  }
  else{
    return ["0","0","0","0"];
  }
}