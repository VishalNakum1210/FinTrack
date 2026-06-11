  import 'package:flutter/material.dart';

  class UserMainPage extends StatefulWidget {
    @override
    State<UserMainPage> createState() => _userMainPage();
  }

  class _userMainPage extends State<UserMainPage> {
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Row(
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 5, right: 10),
                height: 50,
                width: 50,
                child: CircleAvatar(
                  radius: 25,
                  backgroundImage: AssetImage(
                    "assets/image/AccountApplicationLogo.jpg",
                  ),
                ),
              ),
              Text("Welcome, Vishal"),
            ],
          ),
          backgroundColor: Colors.white,
        ),
        body: Container(
          height: double.infinity,
          width: double.infinity,
          color: Color(0xFF8BC24A),

          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: EdgeInsets.only(left: 20, right: 20, top: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                  ),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(left: 20, right: 20, top: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        color: const Color.fromARGB(255, 209, 161, 143),
                      ),

                      // child: Container(
                      //   width: double.infinity,
                      //   height: 60,
                      //   color: Color(0xFF8BC24A),
                      // ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  height: 60,
                  width: 60,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset("assets/image/GreenPlus.png"),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
