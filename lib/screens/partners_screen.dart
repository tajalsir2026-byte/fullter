import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/form_fields.dart';
import '../widgets/gold_table.dart';
import 'forms/partner_form.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final AppStore store = AppStore.instance;

  Future<void> _openForm([Partner? existing]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => PartnerForm(existing: existing)),
    );
  }

  Future<void> _delete(Partner p) async {
    final bool ok = await confirmDialog(
      context,
      title: 'حذف الشريك',
      message: 'حذف "${p.name}"؟\n'
          'مصروفاته الخاصة ستتحوّل إلى "عام" ولن تُحذف.',
    );
    if (!ok) return;
    final bool saved = await store.deletePartner(p.id);
    if (mounted) showMsg(context, saved ? 'تم الحذف' : 'فشل الحفظ', error: !saved);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, Widget? _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: <Widget>[
            // بطاقة ملخص رأس المال والأرباح
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: kGoldLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGold, width: 1.5),
              ),
              child: Column(
                children: <Widget>[
                  const Text(
                    'إجمالي رأس المال',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      fmtMoney(store.totalCapital),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: kDarkGold),
                    ),
                  ),
                  const Divider(height: 24, thickness: 1),

                  // صف المؤشرات الأربعة مع فواصل رأسية وعناوين على سطرين
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _columnItem(
                        'صافي\nالربح',
                        fmtNum(store.netProfit),
                        store.netProfit >= 0 ? kGreen : kRed,
                      ),
                      _divider(),
                      _columnItem(
                        'منصرفات\nعامة',
                        fmtNum(store.generalExpenses),
                        kDarkGold,
                      ),
                      _divider(),
                      _columnItem(
                        'منصرفات\nخاصة',
                        fmtNum(store.privateExpenses),
                        kBlue,
                      ),
                      _divider(),
                      _columnItem(
                        'نسب\nالربح',
                        '${store.totalProfitPercent.toStringAsFixed(1)}%',
                        store.totalProfitPercent == 100 ? kGreen : kRed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (store.partners.isNotEmpty && store.totalProfitPercent != 100)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'تنبيه: مجموع نسب الأرباح ${store.totalProfitPercent.toStringAsFixed(1)}% — يجب ضبطها إلى 100%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kRed, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),

            if (store.partners.isEmpty)
              const EmptyHint(
                icon: Icons.groups,
                text: 'لا يوجد شركاء بعد\nاضغط "شريك جديد" للإضافة',
              )
            else
              ...store.partners.map(_partnerCard),

            if (store.partners.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'صافي المستحق = رأس المال + حصته من الربح اليدوية − مصروفاته الخاصة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11.5),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _columnItem(String title, String value, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 34,
      color: Colors.black12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _partnerCard(Partner p) {
    final double pct = p.profitPercent;
    final double profitShare = store.profitShareOf(p);
    final double spent = store.privateExpensesOf(p.name);
    final double net = store.netForPartner(p);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: kGold,
            child: Text(
              p.name.isNotEmpty ? p.name.characters.first : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(p.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kGoldLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'رأس المال: ${fmtNum(p.capital)} $kCurrency',
                    style: const TextStyle(
                        fontSize: 11,
                        color: kDarkGold,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ربح: ${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(fmtMoney(net),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: net >= 0 ? kGreen : kRed)),
              const Text('صافي المستحق',
                  style: TextStyle(fontSize: 9.5, color: Colors.grey)),
            ],
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                children: <Widget>[
                  _row('رأس المال', fmtMoney(p.capital)),
                  _row('نسبة الربح اليدوية', '${pct.toStringAsFixed(2)}%'),
                  _row('حصته من الربح', fmtMoney(profitShare),
                      color: profitShare >= 0 ? kGreen : kRed),
                  _row('مصروفاته الخاصة', '- ${fmtMoney(spent)}',
                      color: spent > 0 ? kRed : null),
                  const Divider(),
                  _row('صافي المستحق', fmtMoney(net),
                      color: net >= 0 ? kGreen : kRed, bold: true),
                  if (p.phone.isNotEmpty) _row('الهاتف', p.phone),
                  if (p.notes.isNotEmpty) _row('ملاحظات', p.notes),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openForm(p),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('تعديل'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _delete(p),
                        icon: const Icon(Icons.delete, color: kRed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v, {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Expanded(
                child: Text(k,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13))),
            Text(v,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: bold ? 15 : 13.5,
                  color: color,
                )),
          ],
        ),
      );
}
