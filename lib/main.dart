import 'package:flutter/material.dart';
import 'package:pairauth/screens/home_screen.dart';
import 'package:loggy/loggy.dart';

void main() {
  Loggy.initLoggy();
  runApp(const PairAuth());
}

class PairAuth extends StatelessWidget {
  const PairAuth({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pair Auth',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeScreen(),
    );
  }
}
