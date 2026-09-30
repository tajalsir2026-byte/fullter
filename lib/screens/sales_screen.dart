import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/filter_bar.dart';
import '../widgets/form_fields.dart';
import '../widgets/gold_table.dart';
import 'forms/sale_form.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TableFilter filter = TableFilter();
  final AppStore store = AppStore.instance;

  List<Sale> get visible => store.sales
      .where((Sale s) =>
          filter.matchDate(s.date) &&
          filter.matchText(<String>[
            s.buyer,
            s.notes,
            s.weightStr,
            s.sellAmount.toStringAsFixed(0),
          ]))
      .toList();

  Future<void> _openForm([Sale? existing]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => SaleForm(existing: existing)),
    );
  }

  Future<void> _delete(Sale s) async {
    final bool ok = await confirmDialog(
      context,
      title: 'حذف البيع',
      message: 'حذف بيع ${s.weightStr} بمبلغ ${fmtMoney(s.sellAmount)}؟',
    );
    if (!ok) return;
    final bool saved = await store.deleteSale(s.id);
    if (mounted) showMsg(context, saved ? 'تم الحذف' : 'فشل الحفظ', error: !saved);
  }

  void _options(Sale s) {
    final Purchase? src = store.purchaseById(s.purchaseId);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text('بيع ${s.weightStr} — ${fmtMoney(s.sellAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${dateLongStr(s.date)}\n'
                'الربح: ${fmtMoney(s.profit)}'
                '${src == null ? '' : '\nمن مشترى: ${src.weightStr} (${dateStr(src.date)})'}',
              ),
              isThreeLine: true,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit, color: kBlue),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(ctx);
                _openForm(s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: kRed),
              title: const Text('حذف'),
              onTap: () {
                Navigator.pop(ctx);
                _delete(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, Widget? _) {
        final List<Sale> items = visible;
        final int totalUnits = items.fold<int>(0, (int a, Sale s) => a + s.units);
        final double cost =
            items.fold<double>(0, (double a, Sale s) => a + s.buyAmount);
        final double revenue =
            items.fold<double>(0, (double a, Sale s) => a + s.sellAmount);
        final double profit = revenue - cost;

        return Column(
          children: <Widget>[
            FilterBar(
              filter: filter,
              onChanged: () => setState(() {}),
              searchHint: 'بحث بالمشتري أو الملاحظات أو المبلغ...',
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyHint(
                      icon: Icons.sell,
                      text: store.sales.isEmpty
                          ? 'لا توجد مبيعات بعد\nاضغط "بيع جديد" للإضافة'
                          : 'لا توجد نتائج مطابقة للبحث',
                    )
                  : GoldTable(
                      columns: const <GoldCol>[
                        GoldCol('تاريخ', 88),
                        GoldCol('وزن', 80),
                        GoldCol('عيار', 52),
                        GoldCol('التكلفة', 95),
                        GoldCol('البيع', 95),
                        GoldCol('الربح', 95),
                        GoldCol('المشتري', 100),
                        GoldCol('المصدر', 80),
                        GoldCol('ملاحظات', 140),
                      ],
                      rowCount: items.length,
                      onRowTap: (int i) => _options(items[i]),
                      rowBuilder: (int i) {
                        final Sale s = items[i];
                        return <GoldCell>[
                          GoldCell(dateStr(s.date)),
                          GoldCell(s.weightStr, weight: FontWeight.bold),
                          GoldCell(s.purity == 0 ? '—' : '${s.purity}'),
                          GoldCell(fmtNum(s.buyAmount)),
                          GoldCell(fmtNum(s.sellAmount)),
                          GoldCell(fmtNum(s.profit),
                              color: s.profit >= 0 ? kGreen : kRed,
                              weight: FontWeight.bold),
                          GoldCell(s.buyer.isEmpty ? '—' : s.buyer),
                          GoldCell(s.purchaseId == null ? 'يدوي' : 'مرتبط',
                              color: s.purchaseId == null ? null : kBlue),
                          GoldCell(s.notes.isEmpty ? '—' : s.notes),
                        ];
                      },
                      footer: <GoldCell>[
                        const GoldCell('الإجمالي',
                            color: Colors.white, weight: FontWeight.bold),
                        GoldCell(unitsToWeight(totalUnits),
                            color: Colors.amber, weight: FontWeight.bold),
                        const GoldCell('—', color: Colors.white),
                        GoldCell(fmtNum(cost), color: Colors.white),
                        GoldCell(fmtNum(revenue),
                            color: Colors.white, weight: FontWeight.bold),
                        GoldCell(fmtNum(profit),
                            color: profit >= 0
                                ? Colors.lightGreenAccent
                                : Colors.redAccent,
                            weight: FontWeight.bold),
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
