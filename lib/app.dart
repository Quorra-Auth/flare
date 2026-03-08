import 'package:flutter/material.dart';
import 'pages/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flare',
      home: MyHomePage(title: 'LNURL-auth client'),
    );
  }
}

