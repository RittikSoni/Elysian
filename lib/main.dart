import 'package:elysian/utils/kroute.dart';
import 'package:flutter/material.dart';
import 'screens/screens.dart';

void main() => runApp(Elysian());

class Elysian extends StatelessWidget {
  const Elysian({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      title: 'Elysian',
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      home: BottomNav(),
    );
  }
}
