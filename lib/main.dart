import 'package:account/user_pages/main_page.dart';
import 'package:flutter/material.dart';
import 'package:account/authantication/registration_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:account/authantication/login_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Account",
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}