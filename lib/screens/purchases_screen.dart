import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/filter_bar.dart';
import '../widgets/form_fields.dart';
import '../widgets/gold_table.dart';
import 'forms/purchase_form.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final TableFilter filter = TableFilter();
  final AppStore store = AppStore.instance;

  List<Purchase> get visible => store.purchases
      .where((Purchase p) =>
          filter.matchDate(p.date) &&
          filter.matchText(<String>[
            p.seller,
            p.notes,
            p.bankAccount,
            p.weightStr,
            p.amount.toStringAsFixed(0),
          ]))
      .toList();

  Future<void> _openForm([Purchase? existing]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => PurchaseForm(existing: existing)),
    );
  }

  Future<void> _delete(Purchase p) async {
    final bool ok = await confirmDialog(
      context,
      title: 'حذف المشترى',
      message: 'حذف مشترى ${p.weightStr} بمبلغ ${fmtMoney(p.amount)}؟\n'
          'المبيعات المرتبطة به لن تُحذف، سيُفك ارتباطها فقط.',
    );
    if (!ok) return;
    final bool saved = await store.deletePurchase(p.id);
    if (mounted) {
      showMsg(context, saved ? 'تم الحذف' : store.lastError ?? 'فشل الحفظ',
          error: !saved);
    }
  }

  Future<void> _pay(Purchase p) async {
    final TextEditingController ctrl =
        TextEditingController(text: p.pendingAmount.toStringAsFixed(0));
    final double? amount = await showDialog<double>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('تسديد المتبقي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('المتبقي: ${fmtMoney(p.pendingAmount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: kRed)),
            Text('البائع: ${p.seller.isEmpty ? '—' : p.seller}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            NumberField(
                controller: ctrl,
                icon: Icons.payments,
                hint: 'المبلغ المدفوع'),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final double v = parseNum(ctrl.text);
              if (v <= 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('تأكيد',
                style:
                    TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (amount == null) return;
    final bool saved = await store.payPurchase(p.id, amount);
    if (mounted) {
      showMsg(context, saved ? 'تم تسجيل الدفعة' : 'فشل الحفظ', error: !saved);
    }
  }

  void _details(Purchase p) {
    final int sold = store.soldUnitsOf(p.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('مشترى ${p.weightStr}',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold)),
              Text(dateLongStr(p.date),
                  style: const TextStyle(color: Colors.grey)),
              const Divider(height: 24),
              _kv('المبلغ', fmtMoney(p.amount)),
              _kv('المدفوع', fmtMoney(p.paidAmount)),
              _kv('المتبقي', fmtMoney(p.pendingAmount),
                  color: p.pendingAmount > 0 ? kRed : kGreen),
              _kv('تكلفة الجرام', fmtMoney(p.costPerGram)),
              _kv('العيار', p.purity == 0 ? '—' : '${p.purity}'),
              _kv('البائع', p.seller.isEmpty ? '—' : p.seller),
              _kv('رقم الحساب', p.bankAccount.isEmpty ? '—' : p.bankAccount),
              _kv('المباع منه', unitsToWeight(sold)),
              _kv('المتبقي في المخزون', unitsToWeight(p.units - sold),
                  color: kGold),
              if (p.notes.isNotEmpty) _kv('ملاحظات', p.notes),
              if (p.payments.isNotEmpty) ...<Widget>[
                const Divider(height: 24),
                const Text('سجل الدفعات',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...p.payments.map((Payment pay) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle,
                          color: kGreen, size: 20),
                      title: Text(fmtMoney(pay.amount)),
                      subtitle: Text(dateStr(pay.date)),
                    )),
              ],
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (p.pendingAmount > 0)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _pay(p);
                        },
                        icon: const Icon(Icons.payments),
                        label: const Text('تسديد'),
                      ),
                    ),
                  if (p.pendingAmount > 0) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openForm(p);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(p);
                    },
                    icon: const Icon(Icons.delete, color: kRed),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            SizedBox(
                width: 130,
                child: Text(k,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, Widget? _) {
        final List<Purchase> items = visible;
        final int totalUnits =
            items.fold<int>(0, (int s, Purchase p) => s + p.units);
        final double totalAmount =
            items.fold<double>(0, (double s, Purchase p) => s + p.amount);
        final double totalPending =
            items.fold<double>(0, (double s, Purchase p) => s + p.pendingAmount);

        return Column(
          children: <Widget>[
            FilterBar(
              filter: filter,
              onChanged: () => setState(() {}),
              searchHint: 'بحث بالبائع أو الملاحظات أو المبلغ...',
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyHint(
                      icon: Icons.shopping_cart,
                      text: store.purchases.isEmpty
                          ? 'لا توجد مشتريات بعد\nاضغط "مشترى جديد" للإضافة'
                          : 'لا توجد نتائج مطابقة للبحث',
                    )
                  : GoldTable(
                      columns: const <GoldCol>[
                        GoldCol('تاريخ', 88),
                        GoldCol('وزن', 80),
                        GoldCol('عيار', 52),
                        GoldCol('المبلغ', 100),
                        GoldCol('المتبقي', 95),
                        GoldCol('المباع', 80),
                        GoldCol('البائع', 100),
                        GoldCol('رقم الحساب', 120),
                        GoldCol('ملاحظات', 140),
                      ],
                      rowCount: items.length,
                      onRowTap: (int i) => _details(items[i]),
                      rowBuilder: (int i) {
                        final Purchase p = items[i];
                        final int sold = store.soldUnitsOf(p.id);
                        return <GoldCell>[
                          GoldCell(dateStr(p.date)),
                          GoldCell(p.weightStr, weight: FontWeight.bold),
                          GoldCell(p.purity == 0 ? '—' : '${p.purity}'),
                          GoldCell(fmtNum(p.amount)),
                          GoldCell(
                            p.pendingAmount == 0
                                ? '✓'
                                : fmtNum(p.pendingAmount),
                            color: p.pendingAmount > 0 ? kRed : kGreen,
                            weight: FontWeight.bold,
                          ),
                          GoldCell(sold == 0 ? '—' : unitsToWeight(sold),
                              color: sold > 0 ? kBlue : null),
                          GoldCell(p.seller.isEmpty ? '—' : p.seller),
                          GoldCell(
                              p.bankAccount.isEmpty ? '—' : p.bankAccount),
                          GoldCell(p.notes.isEmpty ? '—' : p.notes),
                        ];
                      },
                      footer: <GoldCell>[
                        const GoldCell('الإجمالي',
                            color: Colors.white, weight: FontWeight.bold),
                        GoldCell(unitsToWeight(totalUnits),
                            color: Colors.amber, weight: FontWeight.bold),
                        const GoldCell('—', color: Colors.white),
                        GoldCell(fmtNum(totalAmount),
                            color: Colors.white, weight: FontWeight.bold),
                        GoldCell(fmtNum(totalPending),
                            color: Colors.orangeAccent,
                            weight: FontWeight.bold),
                        const GoldCell('', color: Colors.white),
                        const GoldCell('', color: Colors.white),
                        const GoldCell('', color: Colors.white),
                        GoldCell('${items.length} عملية',
                            color: Colors.white70),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
