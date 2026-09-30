import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/form_fields.dart';

class PartnerForm extends StatefulWidget {
  final Partner? existing;
  const PartnerForm({super.key, this.existing});

  @override
  State<PartnerForm> createState() => _PartnerFormState();
}

class _PartnerFormState extends State<PartnerForm> {
  final AppStore store = AppStore.instance;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController capitalCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final Partner? e = widget.existing;
    if (e != null) {
      nameCtrl.text = e.name;
      capitalCtrl.text = e.capital.toStringAsFixed(0);
      phoneCtrl.text = e.phone;
      notesCtrl.text = e.notes;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    capitalCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    final String name = nameCtrl.text.trim();
    final double capital = parseNum(capitalCtrl.text);

    if (name.isEmpty) {
      showMsg(context, 'الرجاء إدخال اسم الشريك', error: true);
      return;
    }
    if (capital < 0) {
      showMsg(context, 'رأس المال لا يمكن أن يكون سالباً', error: true);
      return;
    }
    final bool duplicate = store.partners.any((Partner p) =>
        p.name.trim() == name && p.id != widget.existing?.id);
    if (duplicate) {
      showMsg(context, 'يوجد شريك بنفس الاسم', error: true);
      return;
    }

    setState(() => saving = true);
    final Partner p = Partner(
      id: widget.existing?.id ?? newId(),
      name: name,
      capital: capital,
      phone: phoneCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
    );

    final bool ok = widget.existing == null
        ? await store.addPartner(p)
        : await store.updatePartner(p);

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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل شريك' : 'شريك جديد'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          const FieldLabel('اسم الشريك', required: true),
          TextField(
              controller: nameCtrl,
              decoration: fieldDecoration(Icons.person)),
          const SizedBox(height: 16),

          const FieldLabel('رأس المال المدفوع', required: true),
          NumberField(
              controller: capitalCtrl,
              icon: Icons.account_balance_wallet,
              suffix: kCurrency),
          const SizedBox(height: 16),

          const FieldLabel('رقم الهاتف'),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: fieldDecoration(Icons.phone),
          ),
          const SizedBox(height: 16),

          const FieldLabel('ملاحظات'),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: fieldDecoration(Icons.notes),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kGoldLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGold.withValues(alpha: 0.5)),
            ),
            child: const Text(
              'نسبة الشريك تُحسب تلقائياً = رأس ماله ÷ إجمالي رأس المال،\n'
              'وحصته من الربح = نسبته × الربح الصافي.',
              style: TextStyle(fontSize: 12.5, color: kDarkGold),
            ),
          ),
          const SizedBox(height: 26),

          SaveButton(
              onPressed: _save, label: isEdit ? 'حفظ التعديلات' : 'حفظ'),
        ],
      ),
    );
  }
}
