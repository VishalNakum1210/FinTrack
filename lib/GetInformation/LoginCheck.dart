import 'package:shared_preferences/shared_preferences.dart';

class Logincheck {
  static Future<bool> loginCheckCondition () async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? phoneNumber = sp.getString("phone_number");
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      await sp.setBool("isLogin", true);
      return true;
    }
    else{
      return false;
    }
  }
}