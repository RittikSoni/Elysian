import 'package:flutter/material.dart';
import 'screens/screens.dart';

void main() => runApp(NetflixUI());

class NetflixUI extends StatelessWidget {
  const NetflixUI({super.key});

  @override
  Widget build(BuildContext context) {
    print("App started");
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      title: 'Elysian',
      home: BottomNav(),
    );
  }
}
