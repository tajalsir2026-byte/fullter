import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(const GoldApp());

const kGold = Color(0xFFB8860B);
const kDarkGold = Color(0xFF4A3800);

class GoldApp extends StatelessWidget {
  const GoldApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابات الذهب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kGold),
        useMaterial3: true,
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const PasswordGate(),
    );
  }
}

// ===== Helpers =====
String fmtNum(double n) {
  final s = n.abs().toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

String weightToString(double w) {
  final g = w.floor();
  final rem = w - g;
  final h = (rem * 10).floor();
  final j = ((rem * 100) - (h * 10)).round();
  return '$g.$h.$j';
}

// ===== Models =====
class Purchase {
  final String id;
  final DateTime date;
  final int grams, habba, juz, purity;
  final double amount, pendingAmount;
  final String seller, bankAccount, notes;

  Purchase({
    required this.id,
    required this.date,
    required this.grams,
    required this.habba,
    required this.juz,
    required this.purity,
    required this.amount,
    required this.pendingAmount,
    required this.seller,
    required this.bankAccount,
    required this.notes,
  });

  double get weight => grams + habba / 10 + juz / 100;
  String get weightStr => '$grams.$habba.$juz';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'grams': grams,
        'habba': habba,
        'juz': juz,
        'purity': purity,
        'amount': amount,
        'pendingAmount': pendingAmount,
        'seller': seller,
        'bankAccount': bankAccount,
        'notes': notes,
      };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        grams: j['grams'] as int,
        habba: j['habba'] as int,
        juz: j['juz'] as int,
        purity: (j['purity'] as num?)?.toInt() ?? 0,
        amount: (j['amount'] as num).toDouble(),
        pendingAmount: (j['pendingAmount'] as num?)?.toDouble() ?? 0,
        seller: (j['seller'] as String?) ?? '',
        bankAccount: (j['bankAccount'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );

  Purchase copyWith({double? pendingAmount}) => Purchase(
        id: id,
        date: date,
        grams: grams,
        habba: habba,
        juz: juz,
        purity: purity,
        amount: amount,
        pendingAmount: pendingAmount ?? this.pendingAmount,
        seller: seller,
        bankAccount: bankAccount,
        notes: notes,
      );
}

class Sale {
  final String id;
  final DateTime date;
  final int grams, habba, juz, purity;
  final double buyAmount, sellAmount;
  final String buyer, notes;

  Sale({
    required this.id,
    required this.date,
    required this.grams,
    required this.habba,
    required this.juz,
    required this.purity,
    required this.buyAmount,
    required this.sellAmount,
    required this.buyer,
    required this.notes,
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
        'buyer': buyer,
        'notes': notes,
      };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        grams: j['grams'] as int,
        habba: j['habba'] as int,
        juz: j['juz'] as int,
        purity: (j['purity'] as num?)?.toInt() ?? 0,
        buyAmount: (j['buyAmount'] as num).toDouble(),
        sellAmount: (j['sellAmount'] as num).toDouble(),
        buyer: (j['buyer'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );
}

// ===== Password Gate =====
class PasswordGate extends StatefulWidget {
  const PasswordGate({super.key});
  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  bool _loading = true;
  bool _unlocked = false;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _saved = prefs.getString('app_password');
      _loading = false;
    });
  }

  Future<void> _set(String p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_password', p);
    setState(() {
      _saved = p;
      _unlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked) return const MainPage();
    return PasswordScreen(
      savedPassword: _saved,
      onSet: _set,
      onUnlock: () => setState(() => _unlocked = true),
    );
  }
}

class PasswordScreen extends StatefulWidget {
  final String? savedPassword;
  final Function(String) onSet;
  final VoidCallback onUnlock;
  const PasswordScreen({
    super.key,
    required this.savedPassword,
    required this.onSet,
    required this.onUnlock,
  });
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final p1 = TextEditingController();
  final p2 = TextEditingController();
  String? err;

  bool get isSetup => widget.savedPassword == null;

  @override
  void dispose() {
    p1.dispose();
    p2.dispose();
    super.dispose();
  }

  void _submit() {
    final v = p1.text.trim();
    if (v.length != 4) {
      setState(() => err = 'يجب أن يكون 4 أرقام');
      return;
    }
    if (isSetup) {
      if (p2.text.trim() != v) {
        setState(() => err = 'الرقم غير مطابق');
        return;
      }
      widget.onSet(v);
    } else {
      if (v != widget.savedPassword) {
        setState(() => err = 'الرقم السري خطأ');
        return;
      }
      widget.onUnlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: kGold),
              const SizedBox(height: 16),
              Text(
                isSetup ? 'إنشاء كلمة سر' : 'أدخل كلمة السر',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isSetup
                    ? 'اختر 4 أرقام لحماية التطبيق'
                    : 'التطبيق محمي بكلمة سر',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: p1,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (_) {
                  if (err != null) setState(() => err = null);
                  if (p1.text.length == 4 && !isSetup) _submit();
                },
              ),
              if (isSetup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: p2,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 12),
                  decoration: InputDecoration(
                    hintText: 'تأكيد ••••',
                    counterText: '',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
              if (err != null) ...[
                const SizedBox(height: 12),
                Text(err!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isSetup ? 'حفظ' : 'دخول',
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Main Page =====
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [PurchasesScreen(), SalesScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: kGold,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'المشتريات'),
          BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'المبيعات'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ===== Purchases Screen =====
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  static const _key = 'purchases_v2';
  List<Purchase> items = [];
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
      items = list.map((e) => Purchase.fromJson(e)).toList();
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> _add() async {
    final r = await Navigator.push<Purchase>(
      context,
      MaterialPageRoute(builder: (_) => const AddPurchasePage()),
    );
    if (r != null) {
      setState(() => items.insert(0, r));
      await _save();
    }
  }

  Future<void> _edit(int i) async {
    final r = await Navigator.push<Purchase>(
      context,
      MaterialPageRoute(builder: (_) => AddPurchasePage(existing: items[i])),
    );
    if (r != null) {
      setState(() => items[i] = r);
      await _save();
    }
  }

  Future<void> _delete(int i) async {
    final ok = await showDialog<bool>(
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
              child: const Text('حذف',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => items.removeAt(i));
      await _save();
    }
  }

  Future<void> _payPending(int i) async {
    final p = items[i];
    if (p.pendingAmount <= 0) return;
    final ctrl =
        TextEditingController(text: p.pendingAmount.toStringAsFixed(0));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسديد المتبقي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المتبقي الحالي: ${fmtNum(p.pendingAmount)} ج.س',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('للبائع: ${p.seller.isEmpty ? "—" : p.seller}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim()) ?? 0;
              if (v <= 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('تأكيد',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (amount == null) return;
    final newPending =
        (p.pendingAmount - amount).clamp(0.0, double.infinity);
    setState(() {
      items[i] = p.copyWith(pendingAmount: newPending);
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newPending == 0
            ? '✓ تم تسديد المتبقي بالكامل'
            : 'تم دفع ${fmtNum(amount)} — المتبقي: ${fmtNum(newPending)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _options(int i) async {
    final hasPending = items[i].pendingAmount > 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPending)
                ListTile(
                  leading: const Icon(Icons.check_circle,
                      color: Colors.green),
                  title: Text(
                      'تسديد المتبقي (${fmtNum(items[i].pendingAmount)} ج.س)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _payPending(i);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('تعديل'),
                onTap: () {
                  Navigator.pop(ctx);
                  _edit(i);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف'),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(i);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get totalWeight => items.fold(0.0, (s, p) => s + p.weight);
  double get totalAmount => items.fold(0.0, (s, p) => s + p.amount);
  double get totalPending => items.fold(0.0, (s, p) => s + p.pendingAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المشتريات'),
        centerTitle: true,
        backgroundColor: kGold,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'لا توجد مشتريات بعد\nاضغط "مشترى جديد" للإضافة\n\nللتعديل/الحذف/التسديد: اضغط على السطر',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        ...List.generate(
                          items.length,
                          (i) => InkWell(
                            onTap: () => _options(i),
                            child: _row(items[i], i),
                          ),
                        ),
                        _totals(),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('مشترى جديد'),
        backgroundColor: kGold,
        foregroundColor: Colors.white,
      ),
    );
  }

  static const double wDate = 90;
  static const double wWeight = 85;
  static const double wPurity = 60;
  static const double wAmount = 110;
  static const double wSeller = 110;
  static const double wBank = 140;
  static const double wPending = 110;
  static const double wNotes = 150;

  Widget _cell(String t, double w,
      {Color color = Colors.black87,
      FontWeight weight = FontWeight.normal,
      Color? bg}) {
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      color: bg,
      alignment: Alignment.center,
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color, fontWeight: weight, fontSize: 12),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: kGold,
      child: Row(
        children: [
          _cell('تاريخ', wDate, color: Colors.white, weight: FontWeight.bold),
          _cell('وزن', wWeight, color: Colors.white, weight: FontWeight.bold),
          _cell('عيار', wPurity, color: Colors.white, weight: FontWeight.bold),
          _cell('المبلغ', wAmount, color: Colors.white, weight: FontWeight.bold),
          _cell('البائع', wSeller, color: Colors.white, weight: FontWeight.bold),
          _cell('رقم الحساب', wBank,
              color: Colors.white, weight: FontWeight.bold),
          _cell('المتبقي', wPending,
              color: Colors.white, weight: FontWeight.bold),
          _cell('ملاحظات', wNotes,
              color: Colors.white, weight: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _row(Purchase p, int i) {
    final bg = i.isEven ? Colors.white : const Color(0xFFFFF8E1);
    return Row(
      children: [
        _cell('${p.date.day}/${p.date.month}/${p.date.year}', wDate, bg: bg),
        _cell(p.weightStr, wWeight, bg: bg),
        _cell(p.purity == 0 ? '—' : '${p.purity}', wPurity, bg: bg),
        _cell(fmtNum(p.amount), wAmount, bg: bg),
        _cell(p.seller.isEmpty ? '—' : p.seller, wSeller, bg: bg),
        _cell(p.bankAccount.isEmpty ? '—' : p.bankAccount, wBank, bg: bg),
        _cell(
          p.pendingAmount == 0
              ? '✓'
              : fmtNum(p.pendingAmount),
          wPending,
          bg: bg,
          color: p.pendingAmount > 0
              ? Colors.red.shade800
              : Colors.green.shade700,
          weight: FontWeight.bold,
        ),
        _cell(p.notes.isEmpty ? '—' : p.notes, wNotes, bg: bg),
      ],
    );
  }

  Widget _totals() {
    return Container(
      color: kDarkGold,
      child: Row(
        children: [
          _cell('الإجمالي', wDate,
              color: Colors.white, weight: FontWeight.bold),
          _cell(weightToString(totalWeight), wWeight,
              color: Colors.amber, weight: FontWeight.bold),
          _cell('—', wPurity, color: Colors.white, weight: FontWeight.bold),
          _cell(fmtNum(totalAmount), wAmount,
              color: Colors.white, weight: FontWeight.bold),
          _cell('', wSeller, color: Colors.white),
          _cell('', wBank, color: Colors.white),
          _cell(fmtNum(totalPending), wPending,
              color: Colors.orangeAccent, weight: FontWeight.bold),
          _cell('', wNotes, color: Colors.white),
        ],
      ),
    );
  }
}

// ===== Sales Screen =====
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  static const _key = 'sales_v1';
  List<Sale> items = [];
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
      items = list.map((e) => Sale.fromJson(e)).toList();
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> _add() async {
    final r = await Navigator.push<Sale>(
      context,
      MaterialPageRoute(builder: (_) => const AddSalePage()),
    );
    if (r != null) {
      setState(() => items.insert(0, r));
      await _save();
    }
  }

  Future<void> _edit(int i) async {
    final r = await Navigator.push<Sale>(
      context,
      MaterialPageRoute(builder: (_) => AddSalePage(existing: items[i])),
    );
    if (r != null) {
      setState(() => items[i] = r);
      await _save();
    }
  }

  Future<void> _delete(int i) async {
    final ok = await showDialog<bool>(
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
              child: const Text('حذف',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => items.removeAt(i));
      await _save();
    }
  }

  Future<void> _options(int i) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('تعديل'),
                onTap: () {
                  Navigator.pop(ctx);
                  _edit(i);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف'),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(i);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get totalWeight => items.fold(0.0, (s, e) => s + e.weight);
  double get totalBuy => items.fold(0.0, (s, e) => s + e.buyAmount);
  double get totalSell => items.fold(0.0, (s, e) => s + e.sellAmount);
  double get totalProfit => items.fold(0.0, (s, e) => s + e.profit);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المبيعات'),
        centerTitle: true,
        backgroundColor: kGold,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'لا توجد مبيعات بعد\nاضغط "بيع جديد" للإضافة\n\nللتعديل/الحذف: اضغط على السطر',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        ...List.generate(
                          items.length,
                          (i) => InkWell(
                            onTap: () => _options(i),
                            child: _row(items[i], i),
                          ),
                        ),
                        _totals(),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('بيع جديد'),
        backgroundColor: kGold,
        foregroundColor: Colors.white,
      ),
    );
  }

  static const double wDate = 90;
  static const double wWeight = 85;
  static const double wPurity = 55;
  static const double wBuy = 100;
  static const double wSell = 100;
  static const double wProfit = 95;
  static const double wBuyer = 100;
  static const double wNotes = 150;

  Widget _cell(String t, double w,
      {Color color = Colors.black87,
      FontWeight weight = FontWeight.normal,
      Color? bg}) {
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      color: bg,
      alignment: Alignment.center,
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color, fontWeight: weight, fontSize: 12),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: kGold,
      child: Row(
        children: [
          _cell('تاريخ', wDate, color: Colors.white, weight: FontWeight.bold),
          _cell('وزن', wWeight, color: Colors.white, weight: FontWeight.bold),
          _cell('عيار', wPurity, color: Colors.white, weight: FontWeight.bold),
          _cell('الشراء', wBuy, color: Colors.white, weight: FontWeight.bold),
          _cell('البيع', wSell, color: Colors.white, weight: FontWeight.bold),
          _cell('الأرباح', wProfit,
              color: Colors.white, weight: FontWeight.bold),
          _cell('المشتري', wBuyer,
              color: Colors.white, weight: FontWeight.bold),
          _cell('ملاحظات', wNotes,
              color: Colors.white, weight: FontWeight.bold),
        ],
      ),
    );
  }

  Widget _row(Sale s, int i) {
    final bg = i.isEven ? Colors.white : const Color(0xFFFFF8E1);
    return Row(
      children: [
        _cell('${s.date.day}/${s.date.month}/${s.date.year}', wDate, bg: bg),
        _cell(s.weightStr, wWeight, bg: bg),
        _cell('${s.purity}', wPurity, bg: bg),
        _cell(fmtNum(s.buyAmount), wBuy, bg: bg),
        _cell(fmtNum(s.sellAmount), wSell, bg: bg),
        _cell(
          fmtNum(s.profit),
          wProfit,
          bg: bg,
          color: s.profit >= 0
              ? Colors.green.shade800
              : Colors.red.shade800,
          weight: FontWeight.bold,
        ),
        _cell(s.buyer.isEmpty ? '—' : s.buyer, wBuyer, bg: bg),
        _cell(s.notes.isEmpty ? '—' : s.notes, wNotes, bg: bg),
      ],
    );
  }

  Widget _totals() {
    return Container(
      color: kDarkGold,
      child: Row(
        children: [
          _cell('الإجمالي', wDate,
              color: Colors.white, weight: FontWeight.bold),
          _cell(weightToString(totalWeight), wWeight,
              color: Colors.amber, weight: FontWeight.bold),
          _cell('—', wPurity, color: Colors.white, weight: FontWeight.bold),
          _cell(fmtNum(totalBuy), wBuy,
              color: Colors.white, weight: FontWeight.bold),
          _cell(fmtNum(totalSell), wSell,
              color: Colors.white, weight: FontWeight.bold),
          _cell(
            fmtNum(totalProfit),
            wProfit,
            color: totalProfit >= 0
                ? Colors.lightGreenAccent
                : Colors.redAccent,
            weight: FontWeight.bold,
          ),
          _cell('', wBuyer, color: Colors.white),
          _cell('', wNotes, color: Colors.white),
        ],
      ),
    );
  }
}

// ===== Settings Screen =====
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    String? err;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('تغيير كلمة السر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: p1,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: const InputDecoration(
                  hintText: 'الرقم الجديد',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: p2,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: const InputDecoration(
                  hintText: 'تأكيد الرقم',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 10),
                Text(err!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
              onPressed: () {
                if (p1.text.trim().length != 4) {
                  setState(() => err = 'يجب أن يكون 4 أرقام');
                  return;
                }
                if (p1.text.trim() != p2.text.trim()) {
                  setState(() => err = 'الرقم غير مطابق');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_password', p1.text.trim());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ تم تغيير كلمة السر'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        backgroundColor: kGold,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.lock, color: kGold),
            title: const Text('تغيير كلمة السر'),
            subtitle: const Text('تعديل الرقم السري الحالي'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _changePassword(context),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'نسخة 1.0 — المرحلة 1',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Add Purchase Page =====
class AddPurchasePage extends StatefulWidget {
  final Purchase? existing;
  const AddPurchasePage({super.key, this.existing});
  @override
  State<AddPurchasePage> createState() => _AddPurchasePageState();
}

class _AddPurchasePageState extends State<AddPurchasePage> {
  late final TextEditingController gramsCtrl;
  late final TextEditingController habbaCtrl;
  late final TextEditingController juzCtrl;
  late final TextEditingController purityCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController pendingCtrl;
  late final TextEditingController sellerCtrl;
  late final TextEditingController bankCtrl;
  late final TextEditingController notesCtrl;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    gramsCtrl =
        TextEditingController(text: e?.grams.toString() ?? '');
    habbaCtrl =
        TextEditingController(text: e?.habba.toString() ?? '');
    juzCtrl = TextEditingController(text: e?.juz.toString() ?? '');
    purityCtrl = TextEditingController(
        text: (e?.purity ?? 0) == 0 ? '' : e!.purity.toString());
    amountCtrl = TextEditingController(
        text: e == null ? '' : e.amount.toStringAsFixed(0));
    pendingCtrl = TextEditingController(
        text: (e?.pendingAmount ?? 0) == 0
            ? ''
            : e!.pendingAmount.toStringAsFixed(0));
    sellerCtrl = TextEditingController(text: e?.seller ?? '');
    bankCtrl = TextEditingController(text: e?.bankAccount ?? '');
    notesCtrl = TextEditingController(text: e?.notes ?? '');
    date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    gramsCtrl.dispose();
    habbaCtrl.dispose();
    juzCtrl.dispose();
    purityCtrl.dispose();
    amountCtrl.dispose();
    pendingCtrl.dispose();
    sellerCtrl.dispose();
    bankCtrl.dispose();
    notesCtrl.dispose();
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
    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final pending = double.tryParse(pendingCtrl.text.trim()) ?? 0;

    if (g == 0 && h == 0 && j == 0) {
      _msg('الرجاء إدخال الوزن');
      return;
    }
    if (amt == 0) {
      _msg('الرجاء إدخال المبلغ');
      return;
    }
    if (h > 9 || j > 9) {
      _msg('الحبة والجزء من 0 إلى 9');
      return;
    }

    Navigator.pop(
      context,
      Purchase(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        grams: g,
        habba: h,
        juz: j,
        purity: pur,
        amount: amt,
        pendingAmount: pending,
        seller: sellerCtrl.text.trim(),
        bankAccount: bankCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
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
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل مشترى' : 'مشترى جديد'),
        centerTitle: true,
        backgroundColor: kGold,
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
              Expanded(
                  child: _numField(gramsCtrl, 'جرام', Icons.scale)),
              const SizedBox(width: 6),
              Expanded(
                  child: _numField(habbaCtrl, 'حبة', Icons.circle)),
              const SizedBox(width: 6),
              Expanded(
                  child: _numField(
                      juzCtrl, 'جزء', Icons.circle_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          _label('العيار (اختياري)'),
          TextField(
            controller: purityCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec(Icons.diamond),
          ),
          const SizedBox(height: 16),
          _label('المبلغ الإجمالي (جنيه)'),
          TextField(
            controller: amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec(Icons.attach_money),
          ),
          const SizedBox(height: 16),
          _label('اسم البائع (صاحب المبلغ)'),
          TextField(
            controller: sellerCtrl,
            decoration: _dec(Icons.person),
          ),
          const SizedBox(height: 16),
          _label('رقم الحساب البنكي'),
          TextField(
            controller: bankCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec(Icons.account_balance),
          ),
          const SizedBox(height: 16),
          _label('المبلغ المتبقي عندنا (للبائع)'),
          TextField(
            controller: pendingCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec(Icons.pending_actions),
          ),
          const SizedBox(height: 16),
          _label('ملاحظات إضافية'),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: _dec(Icons.notes),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'حفظ التعديلات' : 'حفظ',
                  style: const TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
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

// ===== Add Sale Page =====
class AddSalePage extends StatefulWidget {
  final Sale? existing;
  const AddSalePage({super.key, this.existing});
  @override
  State<AddSalePage> createState() => _AddSalePageState();
}

class _AddSalePageState extends State<AddSalePage> {
  late final TextEditingController gramsCtrl;
  late final TextEditingController habbaCtrl;
  late final TextEditingController juzCtrl;
  late final TextEditingController purityCtrl;
  late final TextEditingController buyCtrl;
  late final TextEditingController sellCtrl;
  late final TextEditingController buyerCtrl;
  late final TextEditingController notesCtrl;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    gramsCtrl =
        TextEditingController(text: e?.grams.toString() ?? '');
    habbaCtrl =
        TextEditingController(text: e?.habba.toString() ?? '');
    juzCtrl = TextEditingController(text: e?.juz.toString() ?? '');
    purityCtrl = TextEditingController(
        text: (e?.purity ?? 0) == 0 ? '' : e!.purity.toString());
    buyCtrl = TextEditingController(
        text: e == null ? '' : e.buyAmount.toStringAsFixed(0));
    sellCtrl = TextEditingController(
        text: e == null ? '' : e.sellAmount.toStringAsFixed(0));
    buyerCtrl = TextEditingController(text: e?.buyer ?? '');
    notesCtrl = TextEditingController(text: e?.notes ?? '');
    date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    gramsCtrl.dispose();
    habbaCtrl.dispose();
    juzCtrl.dispose();
    purityCtrl.dispose();
    buyCtrl.dispose();
    sellCtrl.dispose();
    buyerCtrl.dispose();
    notesCtrl.dispose();
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
      _msg('الحبة والجزء من 0 إلى 9');
      return;
    }

    Navigator.pop(
      context,
      Sale(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        grams: g,
        habba: h,
        juz: j,
        purity: pur,
        buyAmount: buy,
        sellAmount: sell,
        buyer: buyerCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
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
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل بيع' : 'بيع جديد'),
        centerTitle: true,
        backgroundColor: kGold,
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
              Expanded(
                  child: _numField(gramsCtrl, 'جرام', Icons.scale)),
              const SizedBox(width: 6),
              Expanded(
                  child: _numField(habbaCtrl, 'حبة', Icons.circle)),
              const SizedBox(width: 6),
              Expanded(
                  child: _numField(
                      juzCtrl, 'جزء', Icons.circle_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          _label('العيار'),
          TextField(
            controller: purityCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec(Icons.diamond),
          ),
          const SizedBox(height: 16),
          _label('مبلغ الشراء (التكلفة)'),
          TextField(
            controller: buyCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec(Icons.shopping_cart),
          ),
          const SizedBox(height: 16),
          _label('مبلغ البيع'),
          TextField(
            controller: sellCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec(Icons.sell),
          ),
          const SizedBox(height: 16),
          _label('المشتري'),
          TextField(
            controller: buyerCtrl,
            decoration: _dec(Icons.person),
          ),
          const SizedBox(height: 16),
          _label('ملاحظات'),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: _dec(Icons.notes),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'حفظ التعديلات' : 'حفظ',
                  style: const TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
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
