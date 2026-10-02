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
      title: 'ط­ط°ظپ ط§ظ„ط´ط±ظٹظƒ',
      message: 'ط­ط°ظپ "${p.name}"طں\n'
          'ظ…طµط±ظˆظپط§طھظ‡ ط§ظ„ط®ط§طµط© ط³طھطھط­ظˆظ‘ظ„ ط¥ظ„ظ‰ "ط¹ط§ظ…" ظˆظ„ظ† طھظڈط­ط°ظپ.',
    );
    if (!ok) return;
    final bool saved = await store.deletePartner(p.id);
    if (mounted) showMsg(context, saved ? 'طھظ… ط§ظ„ط­ط°ظپ' : 'ظپط´ظ„ ط§ظ„ط­ظپط¸', error: !saved);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, Widget? _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: <Widget>[
            // ظ…ظ„ط®طµ
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kGoldLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGold, width: 1.6),
              ),
              child: Column(
                children: <Widget>[
                  const Text('ط¥ط¬ظ…ط§ظ„ظٹ ط±ط£ط³ ط§ظ„ظ…ط§ظ„',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
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
                  const Divider(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _mini('ط§ظ„ط±ط¨ط­ ط§ظ„طµط§ظپظٹ', fmtNum(store.netProfit),
                          store.netProfit >= 0 ? kGreen : kRed),
                      _mini('ط§ظ„ظ…ظ†طµط±ظپط§طھ ط§ظ„ط¹ط§ظ…ط©', fmtNum(store.generalExpenses),
                          kDarkGold),
                      _mini('ظ…ظ†طµط±ظپط§طھ ط®ط§طµط©', fmtNum(store.privateExpenses),
                          kBlue),
                      _mini('ظ…ط¬ظ…ظˆط¹ ظ†ط³ط¨ ط§ظ„ط±ط¨ط­', '${store.totalProfitPercent.toStringAsFixed(1)}%',
                          store.totalProfitPercent == 100 ? kGreen : kRed),
                    ],
                  ),
                ],
              ),
            ),
            if (store.partners.isNotEmpty && store.totalProfitPercent != 100)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'طھظ†ط¨ظٹظ‡: ظ…ط¬ظ…ظˆط¹ ظ†ط³ط¨ ط§ظ„ط£ط±ط¨ط§ط­ ${store.totalProfitPercent.toStringAsFixed(1)}% â€” ظٹط¬ط¨ ط¶ط¨ط·ظ‡ط§ ط¥ظ„ظ‰ 100%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kRed, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),

            if (store.partners.isEmpty)
              const EmptyHint(
                icon: Icons.groups,
                text: 'ظ„ط§ ظٹظˆط¬ط¯ ط´ط±ظƒط§ط، ط¨ط¹ط¯\nط§ط¶ط؛ط· "ط´ط±ظٹظƒ ط¬ط¯ظٹط¯" ظ„ظ„ط¥ط¶ط§ظپط©',
              )
            else
              ...store.partners.map(_partnerCard),

            if (store.partners.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'طµط§ظپظٹ ط§ظ„ظ…ط³طھط­ظ‚ = ط±ط£ط³ ط§ظ„ظ…ط§ظ„ + ط­طµطھظ‡ ظ…ظ† ط§ظ„ط±ط¨ط­ ط§ظ„ظٹط¯ظˆظٹط© âˆ’ ظ…طµط±ظˆظپط§طھظ‡ ط§ظ„ط®ط§طµط©',
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

  Widget _mini(String label, String value, Color color) => Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      );

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
          subtitle: Text(
            'ط±ط£ط³ ط§ظ„ظ…ط§ظ„: ${fmtNum(p.capital)}  â€¢  ط±ط¨ط­: ${pct.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(fmtNum(net),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: net >= 0 ? kGreen : kRed)),
              const Text('طµط§ظپظٹ ط§ظ„ظ…ط³طھط­ظ‚',
                  style: TextStyle(fontSize: 9.5, color: Colors.grey)),
            ],
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                children: <Widget>[
                  _row('ط±ط£ط³ ط§ظ„ظ…ط§ظ„', fmtMoney(p.capital)),
                  _row('ظ†ط³ط¨ط© ط§ظ„ط±ط¨ط­ ط§ظ„ظٹط¯ظˆظٹط©', '${pct.toStringAsFixed(2)}%'),
                  _row('ط­طµطھظ‡ ظ…ظ† ط§ظ„ط±ط¨ط­', fmtMoney(profitShare),
                      color: profitShare >= 0 ? kGreen : kRed),
                  _row('ظ…طµط±ظˆظپط§طھظ‡ ط§ظ„ط®ط§طµط©', '- ${fmtMoney(spent)}',
                      color: spent > 0 ? kRed : null),
                  const Divider(),
                  _row('طµط§ظپظٹ ط§ظ„ظ…ط³طھط­ظ‚', fmtMoney(net),
                      color: net >= 0 ? kGreen : kRed, bold: true),
                  if (p.phone.isNotEmpty) _row('ط§ظ„ظ‡ط§طھظپ', p.phone),
                  if (p.notes.isNotEmpty) _row('ظ…ظ„ط§ط­ط¸ط§طھ', p.notes),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openForm(p),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('طھط¹ط¯ظٹظ„'),
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
