import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const GoldApp());
}

class GoldApp extends StatelessWidget {
  const GoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابات الذهب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB8860B)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Transaction {
  final String id;
  final String type; // buy_gold, sell_gold, expense, income
  final double amount;
  final double weight;
  final String description;
  final DateTime date;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.weight = 0,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'weight': weight,
    'description': description,
    'date': date.toIso8601String(),
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    type: json['type'] as String,
    amount: (json['amount'] as num).toDouble(),
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    description: json['description'] as String,
    date: DateTime.parse(json['date'] as String),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _key = 'gold_transactions_v1';
  List<Transaction> transactions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null) {
      final List list = jsonDecode(data);
      transactions = list.map((e) => Transaction.fromJson(e)).toList();
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(transactions.map((e) => e.toJson()).toList()));
  }

  double _sumOf(String type) => transactions
      .where((t) => t.type == type)
      .fold(0.0, (sum, t) => sum + t.amount);

  double _weightOf(String type) => transactions
      .where((t) => t.type == type)
      .fold(0.0, (sum, t) => sum + t.weight);

  double get totalBuyGold => _sumOf('buy_gold');
  double get totalSellGold => _sumOf('sell_gold');
  double get totalExpenses => _sumOf('expense');
  double get totalOtherIncome => _sumOf('income');

  double get cashBalance =>
      (totalSellGold + totalOtherIncome) - (totalBuyGold + totalExpenses);

  double get goldBalance => _weightOf('buy_gold') - _weightOf('sell_gold');
  double get goldProfit => totalSellGold - totalBuyGold;

  Future<void> _addTransaction() async {
    final result = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
    if (result != null) {
      setState(() => transactions.insert(0, result));
      await _save();
    }
  }

  Future<void> _deleteTransaction(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العملية'),
        content: const Text('هل تريد حذف هذه العملية؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => transactions.removeAt(index));
      await _save();
    }
  }

  String _fmt(double n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابات محل الذهب'),
        centerTitle: true,
        backgroundColor: const Color(0xFFB8860B),
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _buildSummary(),
            const Divider(height: 1),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'لا توجد عمليات بعد\nاضغط زر "عملية جديدة" للإضافة\n\nلحذف عملية: اضغط عليها مطولاً',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (ctx, i) => _buildTile(transactions[i], i),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        icon: const Icon(Icons.add),
        label: const Text('عملية جديدة'),
        backgroundColor: const Color(0xFFB8860B),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFFFF8E1),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _sumCard('المشتريات', totalBuyGold, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _sumCard('المبيعات', totalSellGold, Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _sumCard('المصاريف', totalExpenses, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _sumCard('دخل آخر', totalOtherIncome, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cashBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cashBalance >= 0 ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Text('الرصيد النقدي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  '${_fmt(cashBalance)} ج.س',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: cashBalance >= 0
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('رصيد الذهب', style: TextStyle(fontSize: 12)),
                        Text('${_fmt(goldBalance)} جم',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('ربح الذهب', style: TextStyle(fontSize: 12)),
                        Text('${_fmt(goldProfit)} ج.س',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(_fmt(value),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTile(Transaction t, int index) {
    final info = _typeInfo(t.type);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: info.color.withOpacity(0.15),
        child: Icon(info.icon, color: info.color),
      ),
      title: Text(info.label,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.description.isNotEmpty) Text(t.description),
          Text(
            '${t.date.day}/${t.date.month}/${t.date.year}'
            + (t.weight > 0 ? '  •  ${_fmt(t.weight)} جم' : ''),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      trailing: Text(
        '${_fmt(t.amount)} ج.س',
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 15, color: info.color),
      ),
      onLongPress: () => _deleteTransaction(index),
    );
  }

  _TypeInfo _typeInfo(String type) {
    switch (type) {
      case 'buy_gold':
        return _TypeInfo('شراء ذهب', Icons.shopping_cart, Colors.orange);
      case 'sell_gold':
        return _TypeInfo('بيع ذهب', Icons.sell, Colors.green);
      case 'expense':
        return _TypeInfo('مصروف', Icons.money_off, Colors.red);
      case 'income':
        return _TypeInfo('دخل آخر', Icons.attach_money, Colors.blue);
      default:
        return _TypeInfo('غير معروف', Icons.help, Colors.grey);
    }
  }
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  _TypeInfo(this.label, this.icon, this.color);
}

// ==================== Add Transaction Page ====================

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  String selectedType = 'buy_gold';
  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  DateTime selectedDate = DateTime.now();

  bool get isGold => selectedType == 'buy_gold' || selectedType == 'sell_gold';

  @override
  void dispose() {
    amountCtrl.dispose();
    weightCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _save() {
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء إدخال مبلغ صحيح'),
            backgroundColor: Colors.red),
      );
      return;
    }
    final weight = double.tryParse(weightCtrl.text.trim()) ?? 0;
    final t = Transaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: selectedType,
      amount: amount,
      weight: weight,
      description: descCtrl.text.trim(),
      date: selectedDate,
    );
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عملية جديدة'),
          centerTitle: true,
          backgroundColor: const Color(0xFFB8860B),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('نوع العملية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeChip('buy_gold', 'شراء ذهب', Icons.shopping_cart, Colors.orange),
                _typeChip('sell_gold', 'بيع ذهب', Icons.sell, Colors.green),
                _typeChip('expense', 'مصروف', Icons.money_off, Colors.red),
                _typeChip('income', 'دخل آخر', Icons.attach_money, Colors.blue),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ (ج.س)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (isGold) ...[
              TextField(
                controller: weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الوزن (جرام)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'الوصف (اسم العميل / تفاصيل)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'التاريخ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                  filled: true,
                  fillColor: Colors.white,
                ),
                child: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('حفظ العملية',
                    style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB8860B),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon, Color color) {
    final selected = selectedType == type;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
      onSelected: (_) => setState(() => selectedType = type),
    );
  }
}
