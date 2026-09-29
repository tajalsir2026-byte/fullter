import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'العدّاد',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int count = 0;
  static const String key = 'saved_count';

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  // تحميل الرقم المحفوظ
  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      count = prefs.getInt(key) ?? 0;
    });
  }

  // حفظ الرقم
  Future<void> _saveCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, count);
  }

  void _increment() {
    setState(() {
      count++;
    });
    _saveCount();
  }

  void _decrement() {
    setState(() {
      if (count > 0) count--;
    });
    _saveCount();
  }

  void _reset() {
    setState(() {
      count = 0;
    });
    _saveCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العدّاد'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'عدد الضغطات:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // أزرار الزيادة والنقصان
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // زر النقصان
                _buildRoundButton(
                  icon: Icons.remove,
                  color: Colors.red,
                  onTap: _decrement,
                ),
                const SizedBox(width: 30),
                // زر الزيادة
                _buildRoundButton(
                  icon: Icons.add,
                  color: Colors.green,
                  onTap: _increment,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // زر التصفير
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('تصفير'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'الرقم محفوظ تلقائيًا',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Icon(icon, size: 40, color: Colors.white),
        ),
      ),
    );
  }
}
