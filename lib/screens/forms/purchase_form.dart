import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/form_fields.dart';

class PurchaseForm extends StatefulWidget {
  final Purchase? existing;
  const PurchaseForm({super.key, this.existing});

  @override
  State<PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<PurchaseForm> {
  final TextEditingController purityCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController pendingCtrl = TextEditingController();
  final TextEditingController sellerCtrl = TextEditingController();
  final TextEditingController bankCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  late DateTime date;
  int units = 0;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final Purchase? e = widget.existing;
    date = e?.date ?? DateTime.now();
    units = e?.units ?? 0;
    if (e != null) {
      if (e.purity != 0) purityCtrl.text = '${e.purity}';
      amountCtrl.text = e.amount.toStringAsFixed(0);
      if (e.pendingAmount != 0) {
        pendingCtrl.text = e.pendingAmount.toStringAsFixed(0);
      }
      priceCtrl.text = e.costPerGram.toStringAsFixed(0);
      sellerCtrl.text = e.seller;
      bankCtrl.text = e.bankAccount;
      notesCtrl.text = e.notes;
    }
  }

  @override
  void dispose() {
    purityCtrl.dispose();
    amountCtrl.dispose();
    priceCtrl.dispose();
    pendingCtrl.dispose();
    sellerCtrl.dispose();
    bankCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  /// عند تغيير سعر الجرام يُحسب المبلغ تلقائياً
  void _priceToAmount() {
    final double price = parseNum(priceCtrl.text);
    if (price <= 0 || units <= 0) return;
    amountCtrl.text = (price * units / kUnitsPerGram).toStringAsFixed(0);
    setState(() {});
  }

  /// عند تغيير المبلغ يُحدَّث سعر الجرام المعروض
  void _amountToPrice() {
    final double amount = parseNum(amountCtrl.text);
    if (units <= 0) return;
    priceCtrl.text = (amount * kUnitsPerGram / units).toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _save() async {
    if (saving) return;
    final double amount = parseNum(amountCtrl.text);
    final double pending = parseNum(pendingCtrl.text);

    if (units <= 0) {
      showMsg(context, 'الرجاء إدخال الوزن', error: true);
      return;
    }
    if (amount <= 0) {
      showMsg(context, 'الرجاء إدخال المبلغ', error: true);
      return;
    }
    if (pending < 0) {
      showMsg(context, 'المتبقي لا يمكن أن يكون سالباً', error: true);
      return;
    }
    if (pending > amount) {
      showMsg(context, 'المتبقي أكبر من المبلغ الكلي — راجع الأرقام',
          error: true);
      return;
    }

    setState(() => saving = true);
    final Purchase p = Purchase(
      id: widget.existing?.id ?? newId(),
      date: date,
      units: units,
      purity: parseInt(purityCtrl.text),
      amount: amount,
      pendingAmount: pending,
      seller: sellerCtrl.text.trim(),
      bankAccount: bankCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      payments: widget.existing?.payments,
    );

    final bool ok = widget.existing == null
        ? await AppStore.instance.addPurchase(p)
        : await AppStore.instance.updatePurchase(p);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showMsg(context, 'تم الحفظ');
    } else {
      setState(() => saving = false);
      showMsg(context, AppStore.instance.lastError ?? 'فشل الحفظ', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
    final double amount = parseNum(amountCtrl.text);
    final double pending = parseNum(pendingCtrl.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل مشترى' : 'مشترى جديد'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          const FieldLabel('التاريخ'),
          DateField(date: date, onChanged: (DateTime d) => setState(() => date = d)),
          const SizedBox(height: 16),

          const FieldLabel('الوزن (جرام . حبة . جزء)', required: true),
          WeightInput(
            initialUnits: units,
            onChanged: (int u) {
              units = u;
              _priceToAmount();
            },
          ),
          const SizedBox(height: 16),

          const FieldLabel('العيار'),
          PurityField(controller: purityCtrl),
          const SizedBox(height: 16),

          const FieldLabel('سعر الجرام'),
          NumberField(
            controller: priceCtrl,
            icon: Icons.local_offer,
            suffix: kCurrency,
            onChanged: (_) => _priceToAmount(),
          ),
          const SizedBox(height: 16),

          const FieldLabel('المبلغ الكلي', required: true),
          NumberField(
            controller: amountCtrl,
            icon: Icons.attach_money,
            suffix: kCurrency,
            onChanged: (_) => _amountToPrice(),
          ),
          const SizedBox(height: 16),

          const FieldLabel('المتبقي للبائع (إن وجد)'),
          NumberField(
            controller: pendingCtrl,
            icon: Icons.pending_actions,
            suffix: kCurrency,
            onChanged: (_) => setState(() {}),
          ),
          if (amount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'المدفوع الآن: ${fmtMoney(amount - pending)}',
                style: TextStyle(
                  color: pending > amount ? kRed : kGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 16),

          const FieldLabel('البائع'),
          TextField(
              controller: sellerCtrl,
              decoration: fieldDecoration(Icons.person)),
          const SizedBox(height: 16),

          const FieldLabel('رقم الحساب / البنك'),
          TextField(
              controller: bankCtrl,
              decoration: fieldDecoration(Icons.account_balance)),
          const SizedBox(height: 16),

          const FieldLabel('ملاحظات'),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: fieldDecoration(Icons.notes),
          ),
          const SizedBox(height: 26),

          SaveButton(
            onPressed: _save,
            label: isEdit ? 'حفظ التعديلات' : 'حفظ',
          ),
        ],
      ),
    );
  }
}
