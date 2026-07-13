import 'package:flutter/material.dart';

import 'screens/mypage_screen.dart';

void main() {
  runApp(const MyPageTestApp());
}

class MyPageTestApp extends StatelessWidget {
  const MyPageTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyPageScreen(),
    );
  }
}