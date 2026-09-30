import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models.dart';
import 'helpers.dart';

void main() => runApp(const GoldApp());

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

// ================ Password Gate ================
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
              Text(isSetup ? 'إنشاء كلمة سر' : 'أدخل كلمة السر',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                isSetup ? 'اختر 4 أرقام لحماية التطبيق' : 'التطبيق محمي بكلمة سر',
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

// ================ Main Page ================
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _index = 0;
  final _kPurchases = GlobalKey<PurchasesScreenState>();
  final _kSales = GlobalKey<SalesScreenState>();
  final _kExpenses = GlobalKey<ExpensesScreenState>();
  final _kPartners = GlobalKey<PartnersScreenState>();

  static const _pages = [
    'المشتريات',
    'المبيعات',
    'المنصرفات اليومية',
    'صفحة رأس المال',
  ];

  void _onFAB() {
    switch (_index) {
      case 0:
        _kPurchases.currentState?.openAdd();
        break;
      case 1:
        _kSales.currentState?.openAdd();
        break;
      case 2:
        _kExpenses.currentState?.openAdd();
        break;
      case 3:
        _kPartners.currentState?.openAdd();
        break;
    }
  }

  String get _fabLabel {
    switch (_index) {
      case 0:
        return 'مشترى جديد';
      case 1:
        return 'بيع جديد';
      case 2:
        return 'مصروف جديد';
      case 3:
        return 'شريك جديد';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kGold,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: DropdownButton<int>(
          value: _index,
          isDense: true,
          dropdownColor: kGold,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          underline: const SizedBox(),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          items: List.generate(
            _pages.length,
            (i) => DropdownMenuItem<int>(
              value: i,
              child: Text(_pages[i],
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
          onChanged: (v) => setState(() => _index = v ?? 0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          PurchasesScreen(key: _kPurchases),
          SalesScreen(key: _kSales),
          ExpensesScreen(key: _kExpenses),
          PartnersScreen(key: _kPartners),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFAB,
        icon: const Icon(Icons.add),
        label: Text(_fabLabel),
        backgroundColor: kGold,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ================ Purchases Screen ================
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => PurchasesScreenState();
}

class PurchasesScreenState extends State<PurchasesScreen> {
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

  Future<void> openAdd() async {
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
              child:
                  const Text('حذف', style: TextStyle(color: Colors.red))),
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
            Text('المتبقي: ${fmtNum(p.pendingAmount)} ج.س',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
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
                  leading:
                      const Icon(Icons.check_circle, color: Colors.green),
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
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'لا توجد مشتريات بعد\nاضغط "مشترى جديد" للإضافة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }
    return SingleChildScrollView(
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
      child: Text(t,
          textAlign: TextAlign.center,
          style:
              TextStyle(color: color, fontWeight: weight, fontSize: 12)),
    );
  }

  Widget _header() => Container(
        color: kGold,
        child: Row(children: [
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
        ]),
      );

  Widget _row(Purchase p, int i) {
    final bg = i.isEven ? Colors.white : const Color(0xFFFFF8E1);
    return Row(children: [
      _cell(dateStr(p.date), wDate, bg: bg),
      _cell(p.weightStr, wWeight, bg: bg),
      _cell(p.purity == 0 ? '—' : '${p.purity}', wPurity, bg: bg),
      _cell(fmtNum(p.amount), wAmount, bg: bg),
      _cell(p.seller.isEmpty ? '—' : p.seller, wSeller, bg: bg),
      _cell(p.bankAccount.isEmpty ? '—' : p.bankAccount, wBank, bg: bg),
      _cell(p.pendingAmount == 0 ? '✓' : fmtNum(p.pendingAmount), wPending,
          bg: bg,
          color: p.pendingAmount > 0
              ? Colors.red.shade800
              : Colors.green.shade700,
          weight: FontWeight.bold),
      _cell(p.notes.isEmpty ? '—' : p.notes, wNotes, bg: bg),
    ]);
  }

  Widget _totals() => Container(
        color: kDarkGold,
        child: Row(children: [
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
        ]),
      );
}

// ================ Sales Screen ================
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> {
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

  Future<void> openAdd() async {
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
              child:
                  const Text('حذف', style: TextStyle(color: Colors.red))),
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
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'لا توجد مبيعات بعد\nاضغط "بيع جديد" للإضافة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }
    return SingleChildScrollView(
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
      child: Text(t,
          textAlign: TextAlign.center,
          style:
              TextStyle(color: color, fontWeight: weight, fontSize: 12)),
    );
  }

  Widget _header() => Container(
        color: kGold,
        child: Row(children: [
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
        ]),
      );

  Widget _row(Sale s, int i) {
    final bg = i.isEven ? Colors.white : const Color(0xFFFFF8E1);
    return Row(children: [
      _cell(dateStr(s.date), wDate, bg: bg),
      _cell(s.weightStr, wWeight, bg: bg),
      _cell('${s.purity}', wPurity, bg: bg),
      _cell(fmtNum(s.buyAmount), wBuy, bg: bg),
      _cell(fmtNum(s.sellAmount), wSell, bg: bg),
      _cell(fmtNum(s.profit), wProfit,
          bg: bg,
          color: s.profit >= 0
              ? Colors.green.shade800
              : Colors.red.shade800,
          weight: FontWeight.bold),
      _cell(s.buyer.isEmpty ? '—' : s.buyer, wBuyer, bg: bg),
      _cell(s.notes.isEmpty ? '—' : s.notes, wNotes, bg: bg),
    ]);
  }

  Widget _totals() => Container(
        color: kDarkGold,
        child: Row(children: [
          _cell('الإجمالي', wDate,
              color: Colors.white, weight: FontWeight.bold),
          _cell(weightToString(totalWeight), wWeight,
              color: Colors.amber, weight: FontWeight.bold),
          _cell('—', wPurity, color: Colors.white, weight: FontWeight.bold),
          _cell(fmtNum(totalBuy), wBuy,
              color: Colors.white, weight: FontWeight.bold),
          _cell(fmtNum(totalSell), wSell,
              color: Colors.white, weight: FontWeight.bold),
          _cell(fmtNum(totalProfit), wProfit,
              color: totalProfit >= 0
                  ? Colors.lightGreenAccent
                  : Colors.redAccent,
              weight: FontWeight.bold),
          _cell('', wBuyer, color: Colors.white),
          _cell('', wNotes, color: Colors.white),
        ]),
      );
}

// ================ Expenses Screen ================
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => ExpensesScreenState();
}

class ExpensesScreenState extends State<ExpensesScreen> {
  static const _key = 'expenses_v1';
  List<Expense> items = [];
  List<String> partners = [];
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
      items = list.map((e) => Expense.fromJson(e)).toList();
    }
    final pData = prefs.getString('partners_v1');
    if (pData != null) {
      final list = jsonDecode(pData) as List;
      partners = list.map((e) => Partner.fromJson(e).name).toList();
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> openAdd() async {
    final r = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
          builder: (_) => AddExpensePage(partners: partners)),
    );
    if (r != null) {
      setState(() => items.insert(0, r));
      await _save();
    }
  }

  Future<void> _edit(int i) async {
    final r = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddExpensePage(partners: partners, existing: items[i])),
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
        title: const Text('حذف المصروف'),
        content: const Text('هل تريد حذف هذا المصروف؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('حذف', style: TextStyle(color: Colors.red))),
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

  double get total => items.fold(0.0, (s, e) => s + e.amount);
  double get totalGeneral =>
      items.where((e) => e.isGeneral).fold(0.0, (s, e) => s + e.amount);

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'لا توجد مصروفات بعد\nاضغط "مصروف جديد" للإضافة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }
    return SingleChildScrollView(
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
    );
  }

  static const double wDate = 100;
  static const double wAmount = 110;
  static const double wCategory = 130;
  static const double wType = 90;
  static const double wName = 110;
  static const double wNotes = 170;

  Widget _cell(String t, double w,
      {Color color = Colors.black87,
      FontWeight weight = FontWeight.normal,
      Color? bg}) {
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      color: bg,
      alignment: Alignment.center,
      child: Text(t,
          textAlign: TextAlign.center,
          style:
              TextStyle(color: color, fontWeight: weight, fontSize: 13)),
    );
  }

  Widget _header() => Container(
        color: kGold,
        child: Row(children: [
          _cell('تاريخ', wDate,
              color: Colors.white, weight: FontWeight.bold),
          _cell('المبلغ', wAmount,
              color: Colors.white, weight: FontWeight.bold),
          _cell('الفئة', wCategory,
              color: Colors.white, weight: FontWeight.bold),
          _cell('النوع', wType,
              color: Colors.white, weight: FontWeight.bold),
          _cell('الاسم', wName,
              color: Colors.white, weight: FontWeight.bold),
          _cell('ملاحظات', wNotes,
              color: Colors.white, weight: FontWeight.bold),
        ]),
      );

  Widget _row(Expense e, int i) {
    final bg = i.isEven ? Colors.white : const Color(0xFFFFF8E1);
    final isGen = e.isGeneral;
    return Row(children: [
      _cell(dateStr(e.date), wDate, bg: bg),
      _cell(fmtNum(e.amount), wAmount, bg: bg),
      _cell(e.category, wCategory, bg: bg),
      _cell(isGen ? 'عام' : 'خاص', wType,
          bg: bg,
          color: isGen ? Colors.orange.shade800 : Colors.blue.shade800,
          weight: FontWeight.bold),
      _cell(isGen ? '—' : e.target, wName,
          bg: bg,
          color: isGen ? Colors.black54 : Colors.blue.shade900,
          weight: FontWeight.bold),
      _cell(e.notes.isEmpty ? '—' : e.notes, wNotes, bg: bg),
    ]);
  }

  Widget _totals() => Container(
        color: kDarkGold,
        child: Row(children: [
          _cell('الإجمالي', wDate,
              color: Colors.white, weight: FontWeight.bold),
          _cell(fmtNum(total), wAmount,
              color: Colors.amber, weight: FontWeight.bold),
          _cell('', wCategory, color: Colors.white),
          _cell('عام: ${fmtNum(totalGeneral)}', wType,
              color: Colors.orangeAccent, weight: FontWeight.bold),
          _cell('', wName, color: Colors.white),
          _cell('', wNotes, color: Colors.white),
        ]),
      );
}

// ================ Partners Screen ================
class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});
  @override
  State<PartnersScreen> createState() => PartnersScreenState();
}

class PartnersScreenState extends State<PartnersScreen> {
  static const _key = 'partners_v1';
  List<Partner> items = [];
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
      items = list.map((e) => Partner.fromJson(e)).toList();
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> openAdd() async {
    final r = await Navigator.push<Partner>(
      context,
      MaterialPageRoute(builder: (_) => const AddPartnerPage()),
    );
    if (r != null) {
      setState(() => items.add(r));
      await _save();
    }
  }

  Future<void> _edit(int i) async {
    final r = await Navigator.push<Partner>(
      context,
      MaterialPageRoute(
          builder: (_) => AddPartnerPage(existing: items[i])),
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
        title: const Text('حذف الشريك'),
        content: Text('حذف "${items[i].name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => items.removeAt(i));
      await _save();
    }
  }

  double get totalCapital => items.fold(0.0, (s, p) => s + p.capital);

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGold, width: 2),
          ),
          child: Column(
            children: [
              const Text('إجمالي رأس المال',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('${fmtNum(totalCapital)} ج.س',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: kGold)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'لا يوجد شركاء بعد\nاضغط "شريك جديد" للإضافة',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...List.generate(items.length, (i) {
            final p = items[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: kGold,
                  child: Text(
                    p.name.isNotEmpty ? p.name[0] : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('رأس المال: ${fmtNum(p.capital)} ج.س'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _edit(i);
                    if (v == 'delete') _delete(i);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(
                        value: 'delete',
                        child:
                            Text('حذف', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ================ Settings ================
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
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
                      color: Colors.green, fontWeight: FontWeight.bold)),
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
            child: Text('نسخة 2.1',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ================ Add Purchase ================
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
    gramsCtrl = TextEditingController(text: e?.grams.toString() ?? '');
    habbaCtrl = TextEditingController(text: e?.habba.toString() ?? '');
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
        SnackBar(content: Text(s), backgroundColor: Colors.red));
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
              child: Text(dateStr(date)),
            ),
          ),
          const SizedBox(height: 16),
          _label('الوزن (جرام . حبة . جزء)'),
          Row(children: [
            Expanded(child: _numField(gramsCtrl, 'جرام', Icons.scale)),
            const SizedBox(width: 6),
            Expanded(child: _numField(habbaCtrl, 'حبة', Icons.circle)),
            const SizedBox(width: 6),
            Expanded(
                child: _numField(juzCtrl, 'جزء', Icons.circle_outlined)),
          ]),
          const SizedBox(height: 16),
          _label('العيار (اختياري)'),
          TextField(
              controller: purityCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec(Icons.diamond)),
          const SizedBox(height: 16),
          _label('المبلغ الإجمالي (جنيه)'),
          TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(Icons.attach_money)),
          const SizedBox(height: 16),
          _label('اسم البائع (صاحب المبلغ)'),
          TextField(controller: sellerCtrl, decoration: _dec(Icons.person)),
          const SizedBox(height: 16),
          _label('رقم الحساب البنكي'),
          TextField(
              controller: bankCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec(Icons.account_balance)),
          const SizedBox(height: 16),
          _label('المبلغ المتبقي عندنا'),
          TextField(
              controller: pendingCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(Icons.pending_actions)),
          const SizedBox(height: 16),
          _label('ملاحظات إضافية'),
          TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: _dec(Icons.notes)),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'حفظ التعديلات' : 'حفظ',
                  style: const TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kGold, foregroundColor: Colors.white),
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

// ================ Add Sale ================
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
    gramsCtrl = TextEditingController(text: e?.grams.toString() ?? '');
    habbaCtrl = TextEditingController(text: e?.habba.toString() ?? '');
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
        SnackBar(content: Text(s), backgroundColor: Colors.red));
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
              child: Text(dateStr(date)),
            ),
          ),
          const SizedBox(height: 16),
          _label('الوزن (جرام . حبة . جزء)'),
          Row(children: [
            Expanded(child: _numField(gramsCtrl, 'جرام', Icons.scale)),
            const SizedBox(width: 6),
            Expanded(child: _numField(habbaCtrl, 'حبة', Icons.circle)),
            const SizedBox(width: 6),
            Expanded(
                child: _numField(juzCtrl, 'جزء', Icons.circle_outlined)),
          ]),
          const SizedBox(height: 16),
          _label('العيار'),
          TextField(
              controller: purityCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec(Icons.diamond)),
          const SizedBox(height: 16),
          _label('مبلغ الشراء (التكلفة)'),
          TextField(
              controller: buyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(Icons.shopping_cart)),
          const SizedBox(height: 16),
          _label('مبلغ البيع'),
          TextField(
              controller: sellCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(Icons.sell)),
          const SizedBox(height: 16),
          _label('المشتري'),
          TextField(controller: buyerCtrl, decoration: _dec(Icons.person)),
          const SizedBox(height: 16),
          _label('ملاحظات'),
          TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: _dec(Icons.notes)),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'حفظ التعديلات' : 'حفظ',
                  style: const TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kGold, foregroundColor: Colors.white),
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

// ================ Add Expense (NEW) ================
class AddExpensePage extends StatefulWidget {
  final Expense? existing;
  final List<String> partners;
  const AddExpensePage({super.key, this.existing, required this.partners});
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  late final TextEditingController amountCtrl;
  late final TextEditingController categoryCtrl;
  late final TextEditingController notesCtrl;
  late String target;
  late DateTime date;

  static const _categories = [
    'كهرباء', 'إيجار', 'فطور', 'غداء', 'بيت',
    'صيانة', 'نقل', 'ضيافة', 'رواتب', 'أخرى',
  ];

  bool get isPrivate => target != kGeneral;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    amountCtrl = TextEditingController(
        text: e == null ? '' : e.amount.toStringAsFixed(0));
    categoryCtrl = TextEditingController(text: e?.category ?? '');
    notesCtrl = TextEditingController(text: e?.notes ?? '');
    target = e?.target ?? kGeneral;
    date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    categoryCtrl.dispose();
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

  Future<void> _pickCategory() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('اختر الفئة',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _categories
                      .map((c) => ListTile(
                            title: Text(c),
                            onTap: () => Navigator.pop(ctx, c),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      setState(() => categoryCtrl.text = chosen);
    }
  }

  void _selectGeneral() {
    setState(() => target = kGeneral);
  }

  void _selectPrivate() {
    if (widget.partners.isEmpty) {
      _msg('أضف شركاء أولًا من صفحة رأس المال');
      return;
    }
    setState(() => target = widget.partners.first);
  }

  void _save() {
    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amt <= 0) {
      _msg('الرجاء إدخال المبلغ');
      return;
    }
    if (categoryCtrl.text.trim().isEmpty) {
      _msg('الرجاء اختيار أو كتابة الفئة');
      return;
    }
    Navigator.pop(
      context,
      Expense(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        amount: amt,
        category: categoryCtrl.text.trim(),
        target: target,
        notes: notesCtrl.text.trim(),
      ),
    );
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل مصروف' : 'مصروف جديد'),
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
              child: Text(dateStr(date)),
            ),
          ),
          const SizedBox(height: 16),
          _label('المبلغ (جنيه)'),
          TextField(
            controller: amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec(Icons.attach_money),
          ),
          const SizedBox(height: 16),
          _label('الفئة'),
          InkWell(
            onTap: _pickCategory,
            child: InputDecorator(
              decoration: _dec(Icons.category),
              child: Text(
                categoryCtrl.text.isEmpty
                    ? 'اضغط للاختيار أو اكتب يدويًا'
                    : categoryCtrl.text,
                style: TextStyle(
                    color: categoryCtrl.text.isEmpty
                        ? Colors.grey
                        : Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: categoryCtrl,
            decoration: const InputDecoration(
              hintText: 'أو اكتب فئة جديدة',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 20),

          // ===== نوع المصروف (جديد) =====
          _label('نوع المصروف'),
          Row(
            children: [
              Expanded(
                child: _typeButton(
                  label: 'عام',
                  sublabel: 'يقسم بين الشركاء',
                  icon: Icons.groups,
                  color: Colors.orange,
                  selected: !isPrivate,
                  onTap: _selectGeneral,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _typeButton(
                  label: 'خاص',
                  sublabel: 'على شريك معين',
                  icon: Icons.person,
                  color: Colors.blue,
                  selected: isPrivate,
                  onTap: _selectPrivate,
                ),
              ),
            ],
          ),

          // ===== إذا خاص → عرض الشركاء =====
          if (isPrivate) ...[
            const SizedBox(height: 16),
            _label('اختر الشريك'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: widget.partners.map((p) {
                  final sel = target == p;
                  return RadioListTile<String>(
                    value: p,
                    groupValue: target,
                    onChanged: (v) => setState(() => target = v!),
                    title: Text(
                      p,
                      style: TextStyle(
                        fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? Colors.blue.shade800 : Colors.black87,
                      ),
                    ),
                    activeColor: Colors.blue,
                  );
                }).toList(),
              ),
            ),
          ],

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
                  backgroundColor: kGold, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : color, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                color: selected
                    ? Colors.white.withOpacity(0.9)
                    : Colors.grey,
                fontSize: 11,
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
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
      );

  InputDecoration _dec(IconData icon) => InputDecoration(
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      );
}

// ================ Add Partner ================
class AddPartnerPage extends StatefulWidget {
  final Partner? existing;
  const AddPartnerPage({super.key, this.existing});
  @override
  State<AddPartnerPage> createState() => _AddPartnerPageState();
}

class _AddPartnerPageState extends State<AddPartnerPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController capitalCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    capitalCtrl = TextEditingController(
        text: widget.existing == null
            ? ''
            : widget.existing!.capital.toStringAsFixed(0));
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    capitalCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _msg('الرجاء إدخال الاسم');
      return;
    }
    if (name == kGeneral) {
      _msg('"عام" اسم محجوز، اختر اسمًا آخر');
      return;
    }
    final capital = double.tryParse(capitalCtrl.text.trim()) ?? 0;
    Navigator.pop(
      context,
      Partner(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        capital: capital,
      ),
    );
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل شريك' : 'شريك جديد'),
        centerTitle: true,
        backgroundColor: kGold,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('اسم الشريك',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              hintText: 'مثال: أحمد',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          const Text('رأس المال (جنيه)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          TextField(
            controller: capitalCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'مثال: 30000',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.attach_money),
            ),
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
                  backgroundColor: kGold, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
