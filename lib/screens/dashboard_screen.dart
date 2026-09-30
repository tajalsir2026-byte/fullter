import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/app_store.dart';

/// ============================================================
///  الشاشة الرئيسية: ملخّص كل شيء في مكان واحد
/// ============================================================
class DashboardScreen extends StatelessWidget {
  final void Function(int pageIndex) onGoTo;
  const DashboardScreen({super.key, required this.onGoTo});

  @override
  Widget build(BuildContext context) {
    final AppStore s = AppStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (BuildContext context, Widget? _) {
        final bool overSold = s.inventoryUnits < 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: <Widget>[
            _NetProfitCard(
              netProfit: s.netProfit,
              gross: s.grossProfit,
              general: s.generalExpenses,
            ),
            const SizedBox(height: 12),

            if (overSold)
              _WarningCard(
                text: 'تنبيه: الوزن المباع أكبر من الوزن المشترى بمقدار '
                    '${unitsToWeight(-s.inventoryUnits)} — راجع المشتريات.',
              ),

            // المخزون
            _SectionTitle('المخزون', onTap: () => onGoTo(1)),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    title: 'الرصيد المتبقي',
                    value: unitsToWeight(s.inventoryUnits),
                    sub: 'جرام.حبة.جزء',
                    icon: Icons.inventory_2,
                    color: overSold ? kRed : kGold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'قيمة المخزون',
                    value: fmtNum(s.inventoryValue),
                    sub: kCurrency,
                    icon: Icons.account_balance_wallet,
                    color: kGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    title: 'وزن مشترى',
                    value: unitsToWeight(s.purchasedUnits),
                    sub: '${s.purchases.length} عملية',
                    icon: Icons.shopping_cart,
                    color: kBlue,
                    onTap: () => onGoTo(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'وزن مباع',
                    value: unitsToWeight(s.soldUnits),
                    sub: '${s.sales.length} عملية',
                    icon: Icons.sell,
                    color: kGreen,
                    onTap: () => onGoTo(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatCard(
              title: 'متوسط تكلفة الجرام',
              value: fmtNum(s.avgCostPerGram),
              sub: kCurrency,
              icon: Icons.balance,
              color: kDarkGold,
              wide: true,
            ),

            const SizedBox(height: 16),
            _SectionTitle('الحركة المالية', onTap: () => onGoTo(2)),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    title: 'إجمالي المبيعات',
                    value: fmtNum(s.salesRevenue),
                    sub: kCurrency,
                    icon: Icons.trending_up,
                    color: kGreen,
                    onTap: () => onGoTo(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'إجمالي المشتريات',
                    value: fmtNum(s.purchasedAmount),
                    sub: kCurrency,
                    icon: Icons.trending_down,
                    color: kBlue,
                    onTap: () => onGoTo(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    title: 'مستحق للبائعين',
                    value: fmtNum(s.totalPending),
                    sub: 'ديون عليك',
                    icon: Icons.person_off,
                    color: s.totalPending > 0 ? kRed : kGreen,
                    onTap: () => onGoTo(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'النقد التقديري',
                    value: fmtNum(s.estimatedCash),
                    sub: kCurrency,
                    icon: Icons.payments,
                    color: s.estimatedCash >= 0 ? kGreen : kRed,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _SectionTitle('المنصرفات', onTap: () => onGoTo(3)),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    title: 'منصرفات عامة',
                    value: fmtNum(s.generalExpenses),
                    sub: 'تُخصم من الربح',
                    icon: Icons.receipt_long,
                    color: Colors.orange.shade800,
                    onTap: () => onGoTo(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'منصرفات خاصة',
                    value: fmtNum(s.privateExpenses),
                    sub: 'تُخصم من الشركاء',
                    icon: Icons.person,
                    color: kBlue,
                    onTap: () => onGoTo(4),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _SectionTitle('رأس المال', onTap: () => onGoTo(4)),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    title: 'إجمالي رأس المال',
                    value: fmtNum(s.totalCapital),
                    sub: '${s.partners.length} شريك',
                    icon: Icons.groups,
                    color: kGold,
                    onTap: () => onGoTo(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'ربح المبيعات',
                    value: fmtNum(s.grossProfit),
                    sub: 'قبل المنصرفات',
                    icon: Icons.savings,
                    color: s.grossProfit >= 0 ? kGreen : kRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'الربح الصافي = ربح المبيعات − المنصرفات العامة',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NetProfitCard extends StatelessWidget {
  final double netProfit;
  final double gross;
  final double general;
  const _NetProfitCard({
    required this.netProfit,
    required this.gross,
    required this.general,
  });

  @override
  Widget build(BuildContext context) {
    final bool positive = netProfit >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? <Color>[const Color(0xFF1B5E20), const Color(0xFF43A047)]
              : <Color>[const Color(0xFFB71C1C), const Color(0xFFE53935)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          const Text('الربح الصافي',
              style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              '${fmtNum(netProfit)} $kCurrency',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _mini('ربح المبيعات', fmtNum(gross)),
              Container(width: 1, height: 26, color: Colors.white24),
              _mini('منصرفات عامة', '- ${fmtNum(general)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Column(
        children: <Widget>[
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool wide;

  const _StatCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        value,
                        style: TextStyle(
                            fontSize: wide ? 22 : 18,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                    ),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 10.5, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _SectionTitle(this.text, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: <Widget>[
          Container(width: 4, height: 18, color: kGold),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: const Text('عرض', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final String text;
  const _WarningCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        border: Border.all(color: kRed.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber, color: kRed),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: kRed, fontSize: 13))),
        ],
      ),
    );
  }
}
