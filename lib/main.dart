import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pairauth/screens/home_screen.dart';
import 'package:loggy/loggy.dart';
import './services/http_overrides.dart';

void main() {
  Loggy.initLoggy();
  HttpOverrides.global = MyHttpOverrides();
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
        appBarTheme: AppBarThemeData(
          backgroundColor: const Color.fromARGB(255, 115, 160, 43),
          foregroundColor: Colors.white,
        ),
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeScreen(),
    );
  }
}
