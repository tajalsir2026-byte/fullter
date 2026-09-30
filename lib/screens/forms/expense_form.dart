import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/form_fields.dart';

class ExpenseForm extends StatefulWidget {
  final Expense? existing;
  const ExpenseForm({super.key, this.existing});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final AppStore store = AppStore.instance;

  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController categoryCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  late DateTime date;
  bool isGeneral = true;
  String? partner;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final Expense? e = widget.existing;
    date = e?.date ?? DateTime.now();
    if (e != null) {
      amountCtrl.text = e.amount.toStringAsFixed(0);
      categoryCtrl.text = e.category;
      nameCtrl.text = e.name;
      notesCtrl.text = e.notes;
      isGeneral = e.isGeneral;
      if (!e.isGeneral) partner = e.target;
    }
    // لو الشريك المحفوظ لم يعد موجوداً
    if (partner != null && !store.partnerNames.contains(partner)) {
      partner = null;
      isGeneral = true;
    }
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    categoryCtrl.dispose();
    nameCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    final double amount = parseNum(amountCtrl.text);
    if (amount <= 0) {
      showMsg(context, 'الرجاء إدخال المبلغ', error: true);
      return;
    }
    if (categoryCtrl.text.trim().isEmpty) {
      showMsg(context, 'الرجاء إدخال الفئة', error: true);
      return;
    }
    if (!isGeneral && (partner == null || partner!.isEmpty)) {
      showMsg(context, 'اختر الشريك صاحب المصروف الخاص', error: true);
      return;
    }

    setState(() => saving = true);
    final Expense e = Expense(
      id: widget.existing?.id ?? newId(),
      date: date,
      amount: amount,
      category: categoryCtrl.text.trim(),
      target: isGeneral ? kGeneral : partner!,
      name: isGeneral ? nameCtrl.text.trim() : partner!,
      notes: notesCtrl.text.trim(),
    );

    final bool ok = widget.existing == null
        ? await store.addExpense(e)
        : await store.updateExpense(e);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showMsg(context, 'تم الحفظ');
    } else {
      setState(() => saving = false);
      showMsg(context, store.lastError ?? 'فشل الحفظ', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
    // قائمة الشركاء تُقرأ لحظياً من المخزن — تظهر أي إضافة جديدة فوراً
    final List<String> partners = store.partnerNames;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل مصروف' : 'مصروف جديد'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          const FieldLabel('التاريخ'),
          DateField(
              date: date, onChanged: (DateTime d) => setState(() => date = d)),
          const SizedBox(height: 16),

          const FieldLabel('المبلغ', required: true),
          NumberField(
              controller: amountCtrl,
              icon: Icons.attach_money,
              suffix: kCurrency),
          const SizedBox(height: 16),

          const FieldLabel('الفئة', required: true),
          TextField(
            controller: categoryCtrl,
            decoration: fieldDecoration(Icons.category,
                hint: 'كهرباء، فطور، مواصلات...'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: store.allCategories
                .map((String c) => ChoiceChip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      selected: categoryCtrl.text.trim() == c,
                      selectedColor: kGold.withValues(alpha: 0.25),
                      onSelected: (_) {
                        categoryCtrl.text = c;
                        setState(() {});
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          const FieldLabel('نوع المصروف'),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: true,
                label: Text('عام'),
                icon: Icon(Icons.store),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('خاص بشريك'),
                icon: Icon(Icons.person),
              ),
            ],
            selected: <bool>{isGeneral},
            onSelectionChanged: (Set<bool> v) =>
                setState(() => isGeneral = v.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              isGeneral
                  ? 'المصروف العام يُخصم من الربح الصافي.'
                  : 'المصروف الخاص يُخصم من حساب الشريك وليس من الربح.',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          if (!isGeneral) ...<Widget>[
            const FieldLabel('الشريك', required: true),
            if (partners.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'لا يوجد شركاء — أضف شريكاً أولاً من صفحة "رأس المال والشركاء"',
                  style: TextStyle(color: kRed, fontSize: 13),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: partner,
                isExpanded: true,
                decoration: fieldDecoration(Icons.group),
                items: partners
                    .map((String n) =>
                        DropdownMenuItem<String>(value: n, child: Text(n)))
                    .toList(),
                onChanged: (String? v) => setState(() => partner = v),
              ),
            const SizedBox(height: 16),
          ] else ...<Widget>[
            const FieldLabel('الاسم (اختياري)'),
            TextField(
              controller: nameCtrl,
              decoration: fieldDecoration(Icons.badge,
                  hint: 'اسم المستلم أو صاحب المصروف'),
            ),
            const SizedBox(height: 16),
          ],

          const FieldLabel('ملاحظات'),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: fieldDecoration(Icons.notes),
          ),
          const SizedBox(height: 26),

          SaveButton(
              onPressed: _save, label: isEdit ? 'حفظ التعديلات' : 'حفظ'),
        ],
      ),
    );
  }
}
