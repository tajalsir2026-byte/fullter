import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/form_fields.dart';

class SaleForm extends StatefulWidget {
  final Sale? existing;
  const SaleForm({super.key, this.existing});

  @override
  State<SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<SaleForm> {
  final AppStore store = AppStore.instance;

  final TextEditingController purityCtrl = TextEditingController();
  final TextEditingController buyCtrl = TextEditingController();
  final TextEditingController sellCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController buyerCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  late DateTime date;
  int units = 0;
  String? purchaseId;
  bool saving = false;

  /// المشتريات المتاحة للاختيار (فيها رصيد) + المشترى المرتبط حالياً
  List<Purchase> get sources {
    final List<Purchase> list = store.purchasesWithStock;
    final Purchase? current = store.purchaseById(purchaseId);
    if (current != null && !list.any((Purchase p) => p.id == current.id)) {
      list.insert(0, current);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    final Sale? e = widget.existing;
    date = e?.date ?? DateTime.now();
    units = e?.units ?? 0;
    purchaseId = e?.purchaseId;
    if (e != null) {
      if (e.purity != 0) purityCtrl.text = '${e.purity}';
      buyCtrl.text = e.buyAmount.toStringAsFixed(0);
      sellCtrl.text = e.sellAmount.toStringAsFixed(0);
      if (e.units > 0) {
        priceCtrl.text =
            (e.sellAmount * kUnitsPerGram / e.units).toStringAsFixed(0);
      }
      buyerCtrl.text = e.buyer;
      notesCtrl.text = e.notes;
    }
  }

  @override
  void dispose() {
    purityCtrl.dispose();
    buyCtrl.dispose();
    sellCtrl.dispose();
    priceCtrl.dispose();
    buyerCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  /// الوزن المتاح من المشترى المختار (مع استثناء هذه العملية عند التعديل)
  int get availableUnits {
    final Purchase? p = store.purchaseById(purchaseId);
    if (p == null) return -1; // غير مرتبط = بلا حد
    int sold = store.soldUnitsOf(p.id);
    if (widget.existing != null && widget.existing!.purchaseId == p.id) {
      sold -= widget.existing!.units;
    }
    return p.units - sold;
  }

  /// يحسب التكلفة تلقائياً من المشترى المرتبط
  void _recalcCost() {
    final Purchase? p = store.purchaseById(purchaseId);
    if (p == null || units <= 0) return;
    buyCtrl.text = (p.costPerUnit * units).toStringAsFixed(0);
  }

  void _priceToSell() {
    final double price = parseNum(priceCtrl.text);
    if (price <= 0 || units <= 0) return;
    sellCtrl.text = (price * units / kUnitsPerGram).toStringAsFixed(0);
  }

  void _sellToPrice() {
    if (units <= 0) return;
    priceCtrl.text =
        (parseNum(sellCtrl.text) * kUnitsPerGram / units).toStringAsFixed(0);
  }

  Future<void> _save() async {
    if (saving) return;
    final double buy = parseNum(buyCtrl.text);
    final double sell = parseNum(sellCtrl.text);

    if (units <= 0) {
      showMsg(context, 'الرجاء إدخال الوزن', error: true);
      return;
    }
    if (sell <= 0) {
      showMsg(context, 'الرجاء إدخال مبلغ البيع', error: true);
      return;
    }
    if (buy < 0 || sell < 0) {
      showMsg(context, 'المبالغ لا يمكن أن تكون سالبة', error: true);
      return;
    }
    final int avail = availableUnits;
    if (avail >= 0 && units > avail) {
      showMsg(context,
          'الوزن أكبر من المتاح في المشترى المختار (${unitsToWeight(avail)})',
          error: true);
      return;
    }
    // تحذير غير مانع عند البيع بدون رصيد كافٍ في المخزون الكلي
    if (purchaseId == null) {
      int stock = store.inventoryUnits;
      if (widget.existing != null) stock += widget.existing!.units;
      if (units > stock) {
        final bool go = await confirmDialog(
          context,
          title: 'تنبيه المخزون',
          message:
              'الوزن المباع أكبر من رصيد المخزون (${unitsToWeight(stock)}).\n'
              'هل تريد المتابعة على أي حال؟',
          okLabel: 'متابعة',
          okColor: kGold,
        );
        if (!go) return;
      }
    }

    setState(() => saving = true);
    final Sale s = Sale(
      id: widget.existing?.id ?? newId(),
      date: date,
      units: units,
      purity: parseInt(purityCtrl.text),
      buyAmount: buy,
      sellAmount: sell,
      buyer: buyerCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      purchaseId: purchaseId,
    );

    final bool ok = widget.existing == null
        ? await store.addSale(s)
        : await store.updateSale(s);

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
    final double profit = parseNum(sellCtrl.text) - parseNum(buyCtrl.text);
    final int avail = availableUnits;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل بيع' : 'بيع جديد'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          const FieldLabel('التاريخ'),
          DateField(
              date: date, onChanged: (DateTime d) => setState(() => date = d)),
          const SizedBox(height: 16),

          // ربط بالمخزون
          const FieldLabel('البيع من أي مشترى؟'),
          DropdownButtonFormField<String?>(
            initialValue: purchaseId,
            isExpanded: true,
            decoration: fieldDecoration(Icons.inventory_2),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('بدون ربط (إدخال التكلفة يدوياً)'),
              ),
              ...sources.map((Purchase p) => DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(
                      '${p.weightStr} — ${dateStr(p.date)} — متبقي '
                      '${unitsToWeight(store.remainingUnitsOf(p))}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (String? v) {
              setState(() {
                purchaseId = v;
                final Purchase? p = store.purchaseById(v);
                if (p != null) {
                  if (p.purity != 0) purityCtrl.text = '${p.purity}';
                  _recalcCost();
                }
              });
            },
          ),
          if (avail >= 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'المتاح للبيع من هذا المشترى: ${unitsToWeight(avail)}',
                style: TextStyle(
                    color: units > avail ? kRed : kBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 16),

          const FieldLabel('الوزن (جرام . حبة . جزء)', required: true),
          WeightInput(
            initialUnits: units,
            onChanged: (int u) {
              units = u;
              _recalcCost();
              _priceToSell();
              setState(() {});
            },
          ),
          const SizedBox(height: 16),

          const FieldLabel('العيار'),
          PurityField(controller: purityCtrl),
          const SizedBox(height: 16),

          const FieldLabel('التكلفة (مبلغ الشراء)'),
          NumberField(
            controller: buyCtrl,
            icon: Icons.shopping_cart,
            suffix: kCurrency,
            onChanged: (_) => setState(() {}),
          ),
          if (purchaseId != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('محسوبة تلقائياً من المشترى المختار (يمكن تعديلها)',
                  style: TextStyle(color: Colors.grey, fontSize: 11.5)),
            ),
          const SizedBox(height: 16),

          const FieldLabel('سعر بيع الجرام'),
          NumberField(
            controller: priceCtrl,
            icon: Icons.local_offer,
            suffix: kCurrency,
            onChanged: (_) {
              _priceToSell();
              setState(() {});
            },
          ),
          const SizedBox(height: 16),

          const FieldLabel('مبلغ البيع', required: true),
          NumberField(
            controller: sellCtrl,
            icon: Icons.sell,
            suffix: kCurrency,
            onChanged: (_) {
              _sellToPrice();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),

          // معاينة الربح
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (profit >= 0 ? kGreen : kRed).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: (profit >= 0 ? kGreen : kRed).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: <Widget>[
                Icon(profit >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: profit >= 0 ? kGreen : kRed),
                const SizedBox(width: 10),
                const Text('الربح المتوقع',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(fmtMoney(profit),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: profit >= 0 ? kGreen : kRed)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const FieldLabel('المشتري'),
          TextField(
              controller: buyerCtrl,
              decoration: fieldDecoration(Icons.person)),
          const SizedBox(height: 16),

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
