import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/filter_bar.dart';
import '../widgets/form_fields.dart';
import '../widgets/gold_table.dart';
import 'forms/expense_form.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final TableFilter filter = TableFilter();
  final AppStore store = AppStore.instance;

  List<Expense> get visible => store.expenses
      .where((Expense e) =>
          filter.matchDate(e.date) &&
          filter.matchText(<String>[
            e.category,
            e.name,
            e.target,
            e.notes,
            e.amount.toStringAsFixed(0),
          ]))
      .toList();

  Future<void> _openForm([Expense? existing]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => ExpenseForm(existing: existing)),
    );
  }

  Future<void> _delete(Expense e) async {
    final bool ok = await confirmDialog(
      context,
      title: 'حذف المصروف',
      message: 'حذف ${e.category} بمبلغ ${fmtMoney(e.amount)}؟',
    );
    if (!ok) return;
    final bool saved = await store.deleteExpense(e.id);
    if (mounted) showMsg(context, saved ? 'تم الحذف' : 'فشل الحفظ', error: !saved);
  }

  void _options(Expense e) {
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
              title: Text('${e.category} — ${fmtMoney(e.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${dateLongStr(e.date)}\n${e.isGeneral ? 'مصروف عام' : 'خاص بـ ${e.target}'}'),
              isThreeLine: true,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit, color: kBlue),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(ctx);
                _openForm(e);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: kRed),
              title: const Text('حذف'),
              onTap: () {
                Navigator.pop(ctx);
                _delete(e);
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
        final List<Expense> items = visible;
        final double total =
            items.fold<double>(0, (double s, Expense e) => s + e.amount);
        final double general = items
            .where((Expense e) => e.isGeneral)
            .fold<double>(0, (double s, Expense e) => s + e.amount);

        return Column(
          children: <Widget>[
            FilterBar(
              filter: filter,
              onChanged: () => setState(() {}),
              searchHint: 'بحث بالفئة أو الاسم أو المبلغ...',
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyHint(
                      icon: Icons.receipt_long,
                      text: store.expenses.isEmpty
                          ? 'لا توجد مصروفات بعد\nاضغط "مصروف جديد" للإضافة'
                          : 'لا توجد نتائج مطابقة للبحث',
                    )
                  : GoldTable(
                      columns: const <GoldCol>[
                        GoldCol('تاريخ', 95),
                        GoldCol('المبلغ', 100),
                        GoldCol('الفئة', 120),
                        GoldCol('النوع', 80),
                        GoldCol('الاسم', 110),
                        GoldCol('ملاحظات', 160),
                      ],
                      rowCount: items.length,
                      onRowTap: (int i) => _options(items[i]),
                      rowBuilder: (int i) {
                        final Expense e = items[i];
                        return <GoldCell>[
                          GoldCell(dateStr(e.date)),
                          GoldCell(fmtNum(e.amount),
                              weight: FontWeight.bold),
                          GoldCell(e.category.isEmpty ? '—' : e.category),
                          GoldCell(e.isGeneral ? 'عام' : 'خاص',
                              color: e.isGeneral
                                  ? Colors.orange.shade800
                                  : kBlue,
                              weight: FontWeight.bold),
                          GoldCell(e.name.isEmpty ? '—' : e.name),
                          GoldCell(e.notes.isEmpty ? '—' : e.notes),
                        ];
                      },
                      footer: <GoldCell>[
                        const GoldCell('الإجمالي',
                            color: Colors.white, weight: FontWeight.bold),
                        GoldCell(fmtNum(total),
                            color: Colors.amber, weight: FontWeight.bold),
                        const GoldCell('', color: Colors.white),
                        GoldCell('عام: ${fmtNum(general)}',
                            color: Colors.orangeAccent,
                            weight: FontWeight.bold),
                        GoldCell('خاص: ${fmtNum(total - general)}',
                            color: Colors.lightBlueAccent,
                            weight: FontWeight.bold),
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
