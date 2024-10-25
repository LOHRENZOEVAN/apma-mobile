import 'package:apma/my_homepage.dart';
import 'package:flutter/material.dart';

class Apma extends StatelessWidget {
  const Apma({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'apma',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 74, 189, 95)),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,  // This removes the debug banner
    );
  }
}
