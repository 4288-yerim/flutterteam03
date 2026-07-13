import 'package:flutter/material.dart';
import 'package:flutterteam03/screens/splash/splash_screen.dart';
import 'package:flutterteam03/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // 시스템 다크모드 설정을 따라감
      home: const SplashScreen(),
    );
  }
}