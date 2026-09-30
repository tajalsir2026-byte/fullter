import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(const GoldApp());

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

class Deal {
  final String id;
  final DateTime date;
  final int grams, habba, juz, purity;
  final double buyAmount, sellAmount;

  Deal({
    required this.id,
    required this.date,
    required this.grams,
    required this.habba,
    required this.juz,
    required this.purity,
    required this.buyAmount,
    required this.sellAmount,
  });

  double get weight => grams + habba / 10 + juz / 100;
  double get profit => sellAmount - buyAmount;
  String get weightStr => '$grams.$habba.$juz';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'grams': grams,
        'habba': habba,
        'juz': juz,
        'purity': purity,
        'buyAmount': buyAmount,
        'sellAmount': sellAmount,
      };

  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        grams: j['grams'] as int,
        habba: j['habba'] as int,
        juz: j['juz'] as int,
        purity: j['purity'] as int,
        buyAmount: (j['buyAmount'] as num).toDouble(),
        sellAmount: (j['sellAmount'] as num).toDouble(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _key = 'gold_deals_v1';
  List<Deal> deals = [];
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
      final list = jsonDecode(data) as List;
      deals = list.map((e) => Deal.fromJson(e)).toList();
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(deals.map((e) => e.toJson()).toList()));
  }

  Future<void> _addDeal() async {
    final result = await Navigator.push<Deal>(
      context,
      MaterialPageRoute(builder: (_) => const AddDealPage()),
    );
    if (result != null) {
      setState(() => deals.insert(0, result));
      await _save();
    }
  }

  Future<void> _deleteDeal(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السطر'),
        content: const Text('هل تريد حذف هذا السطر؟'),
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
    if (ok == true) {
      setState(() => deals.removeAt(i));
      await _save();
    }
  }

  String _fmt(double n) {
    final s = n.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return (n < 0 ? '-' : '') + buf.toString();
  }

  double get totalWeight => deals.fold(0.0, (s, d) => s + d.weight);
  double get totalBuy => deals.fold(0.0, (s, d) => s + d.buyAmount);
  double get totalSell => deals.fold(0.0, (s, d) => s + d.sellAmount);
  double get totalProfit => deals.fold(0.0, (s, d) => s + d.profit);

  String get totalWeightStr {
    final g = totalWeight.floor();
    final rem = totalWeight - g;
    final h = (rem * 10).floor();
    final j = ((rem * 100) - (h * 10)).round();
    return '$g.$h.$j';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابات الذهب'),
        centerTitle: true,
        backgroundColor: const Color(0xFFB8860B),
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: deals.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'لا توجد عمليات بعد\nاضغط "عملية جديدة" للإضافة\n\nلحذف سطر: اضغط عليه مطولًا',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                ),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerRow(),
                      ...List.generate(deals.length, (i) {
                        return InkWell(
                          onLongPress: () => _deleteDeal(i),
                          child: _dealRow(deals[i], i),
                        );
                      }),
                      _totalsRow(),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDeal,
        icon: const Icon(Icons.add),
        label: const Text('عملية جديدة'),
        backgroundColor: const Color(0xFFB8860B),
        foregroundColor: Colors.white,
      ),
    );
  }

  static const double wDate = 95;
  static const double wWeight = 110;
  static const double wPurity = 70;
  static const double wBuy = 120;
  static const double wSell = 120;
  static const double wProfit = 120;

  Widget _cell(String text, double width,
      {Color color = Colors.black87,
      FontWeight weight = FontWeight.normal,
      Color? bg}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      color: bg,
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: weight,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      color: const Color(0xFFB8860B),
      child: Row(
        children: [
          _cell('تاريخ', wDate, color: Colors.white, weight: FontWeight.bold),
          _cell('وزن', wWeight, color: Colors.white, weight: FontWeight.bold),
          _cell('عيار', wPurity, color: Colors.white, weight: FontWeight.bold),
          _cell('مبلغ الشراء', wBuy,
              color: Colors.white, weight: FontWeight.bold),
          _cell('مبلغ البيع', wSell,
              color: Colors.white, weight: FontWeight.bold),
          _cell('الأرباح', wProfit,
              color: Colors.white, weight: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _dealRow(Deal d, int i) {
    final bg = i.isEven ? Colors.white : const Color(0xFFFFF8E1);
    return Row(
      children: [
        _cell('${d.date.day}/${d.date.month}/${d.date.year}', wDate, bg: bg),
        _cell(d.weightStr, wWeight, bg: bg),
        _cell('${d.purity}', wPurity, bg: bg),
        _cell(_fmt(d.buyAmount), wBuy, bg: bg),
        _cell(_fmt(d.sellAmount), wSell, bg: bg),
        _cell(
          _fmt(d.profit),
          wProfit,
          bg: bg,
          color: d.profit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
          weight: FontWeight.bold,
        ),
      ],
    );
  }

  Widget _totalsRow() {
    return Container(
      color: const Color(0xFF4A3800),
      child: Row(
        children: [
          _cell('الإجمالي', wDate,
              color: Colors.white, weight: FontWeight.bold),
          _cell(totalWeightStr, wWeight,
              color: Colors.amber, weight: FontWeight.bold),
          _cell('—', wPurity, color: Colors.white, weight: FontWeight.bold),
          _cell(_fmt(totalBuy), wBuy,
              color: Colors.white, weight: FontWeight.bold),
          _cell(_fmt(totalSell), wSell,
              color: Colors.white, weight: FontWeight.bold),
          _cell(
            _fmt(totalProfit),
            wProfit,
            color:
                totalProfit >= 0 ? Colors.lightGreenAccent : Colors.redAccent,
            weight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
}

// ======================= Add Page =======================

class AddDealPage extends StatefulWidget {
  const AddDealPage({super.key});
  @override
  State<AddDealPage> createState() => _AddDealPageState();
}

class _AddDealPageState extends State<AddDealPage> {
  final gramsCtrl = TextEditingController();
  final habbaCtrl = TextEditingController();
  final juzCtrl = TextEditingController();
  final purityCtrl = TextEditingController();
  final buyCtrl = TextEditingController();
  final sellCtrl = TextEditingController();
  DateTime date = DateTime.now();

  @override
  void dispose() {
    gramsCtrl.dispose();
    habbaCtrl.dispose();
    juzCtrl.dispose();
    purityCtrl.dispose();
    buyCtrl.dispose();
    sellCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => date = p);
  }

  void _save() {
    final g = int.tryParse(gramsCtrl.text.trim()) ?? 0;
    final h = int.tryParse(habbaCtrl.text.trim()) ?? 0;
    final j = int.tryParse(juzCtrl.text.trim()) ?? 0;
    final pur = int.tryParse(purityCtrl.text.trim()) ?? 0;
    final buy = double.tryParse(buyCtrl.text.trim()) ?? 0;
    final sell = double.tryParse(sellCtrl.text.trim()) ?? 0;

    if (g == 0 && h == 0 && j == 0) {
      _msg('الرجاء إدخال الوزن');
      return;
    }
    if (buy == 0 && sell == 0) {
      _msg('الرجاء إدخال مبلغ الشراء أو البيع');
      return;
    }
    if (h > 9 || j > 9) {
      _msg('الحبة والجزء يجب أن يكونا من 0 إلى 9');
      return;
    }

    Navigator.pop(
      context,
      Deal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        grams: g,
        habba: h,
        juz: j,
        purity: pur,
        buyAmount: buy,
        sellAmount: sell,
      ),
    );
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سطر جديد'),
          centerTitle: true,
          backgroundColor: const Color(0xFFB8860B),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label('التاريخ'),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: _dec(Icons.calendar_today),
                child: Text('${date.day}/${date.month}/${date.year}'),
              ),
            ),
            const SizedBox(height: 16),
            _label('الوزن (جرام . حبة . جزء)'),
            Row(
              children: [
                Expanded(child: _numField(gramsCtrl, 'جرام', Icons.scale)),
                const SizedBox(width: 6),
                Expanded(child: _numField(habbaCtrl, 'حبة', Icons.circle)),
                const SizedBox(width: 6),
                Expanded(
                    child: _numField(juzCtrl, 'جزء', Icons.circle_outlined)),
              ],
            ),
            const SizedBox(height: 16),
            _label('العيار (مثل: 875، 916، 999)'),
            TextField(
              controller: purityCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec(Icons.diamond),
            ),
            const SizedBox(height: 16),
            _label('مبلغ الشراء (جنيه)'),
            TextField(
              controller: buyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(Icons.shopping_cart),
            ),
            const SizedBox(height: 16),
            _label('مبلغ البيع (جنيه)'),
            TextField(
              controller: sellCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(Icons.sell),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('حفظ', style: TextStyle(fontSize: 18)),
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

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  InputDecoration _dec(IconData icon) => InputDecoration(
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _numField(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
