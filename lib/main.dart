import 'package:flutter/material.dart';

void main() => runApp(const TestApp());

class TestApp extends StatelessWidget {
  const TestApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('اختبار'),
          backgroundColor: const Color(0xFFB8860B),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('التطبيق شغّال!', style: TextStyle(fontSize: 30)),
        ),
      ),
    );
  }
}
