import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const DongxinApp());
}

class DongxinApp extends StatelessWidget {
  const DongxinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '懂心',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5AA9FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07111F),
      ),
      home: const DongxinHomePage(),
    );
  }
}
