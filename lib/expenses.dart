import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models.dart';
import 'helpers.dart';

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
  static const double wName = 130;
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
      _cell(e.target.isEmpty ? '—' : e.target, wName,
          bg: bg,
          color: e.target.isEmpty
              ? Colors.black54
              : (isGen ? Colors.orange.shade900 : Colors.blue.shade900),
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

// ================ Add Expense ================
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
  late final TextEditingController nameCtrl;
  late String type;
  late DateTime date;

  static const _categories = [
    'كهرباء', 'إيجار', 'فطور', 'غداء', 'بيت',
    'صيانة', 'نقل', 'ضيافة', 'رواتب', 'سلفة', 'أخرى',
  ];

  bool get isPrivate => type == 'خاص';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    amountCtrl = TextEditingController(
        text: e == null ? '' : e.amount.toStringAsFixed(0));
    categoryCtrl = TextEditingController(text: e?.category ?? '');
    notesCtrl = TextEditingController(text: e?.notes ?? '');
    final isGen = e == null || e.isGeneral;
    type = isGen ? kGeneral : 'خاص';
    nameCtrl = TextEditingController(
        text: isGen ? (e?.target ?? '') : (e?.target ?? ''));
    date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    categoryCtrl.dispose();
    notesCtrl.dispose();
    nameCtrl.dispose();
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
    setState(() => type = kGeneral);
  }

  void _selectPrivate() {
    setState(() => type = 'خاص');
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
    if (isPrivate && nameCtrl.text.trim().isEmpty) {
      _msg('الرجاء إدخال اسم الشخص (لأنه "خاص")');
      return;
    }
    final name = nameCtrl.text.trim();
    Navigator.pop(
      context,
      Expense(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: date,
        amount: amt,
        category: categoryCtrl.text.trim(),
        target: isPrivate ? name : name,
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

          // ===== نوع المصروف =====
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
                  sublabel: 'على شخص معين',
                  icon: Icons.person,
                  color: Colors.blue,
                  selected: isPrivate,
                  onTap: _selectPrivate,
                ),
              ),
            ],
          ),

          // ===== اسم الشخص (يظهر دائمًا) =====
          const SizedBox(height: 16),
          _label(isPrivate
              ? 'اسم الشخص (إجباري)'
              : 'اسم من أخذ المال (اختياري)'),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              hintText: isPrivate
                  ? 'مثال: محمد'
                  : 'مثال: أحمد (إن كان معروف)',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),

          // ===== اقتراحات سريعة من الشركاء =====
          if (widget.partners.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('اختيار سريع (الشركاء):',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.partners.map((p) {
                final sel = nameCtrl.text.trim() == p;
                return ChoiceChip(
                  label: Text(p),
                  selected: sel,
                  selectedColor:
                      isPrivate ? Colors.blue.shade100 : Colors.orange.shade100,
                  onSelected: (_) {
                    setState(() => nameCtrl.text = p);
                  },
                );
              }).toList(),
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
