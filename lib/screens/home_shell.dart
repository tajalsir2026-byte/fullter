import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'calculator_screen.dart';
import 'gold_price_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'forms/expense_form.dart';
import 'forms/partner_form.dart';
import 'forms/purchase_form.dart';
import 'forms/sale_form.dart';
import 'partners_screen.dart';
import 'purchases_screen.dart';
import 'sales_screen.dart';
import 'settings_screen.dart';

/// الهيكل الرئيسي: قائمة منسدلة للتنقل + زر إضافة متغيّر حسب الصفحة
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'الرئيسية',
    'المشتريات',
    'المبيعات',
    'المنصرفات اليومية',
    'رأس المال والشركاء',
  ];

  static const List<IconData> _icons = <IconData>[
    Icons.dashboard,
    Icons.shopping_cart,
    Icons.sell,
    Icons.receipt_long,
    Icons.groups,
  ];

  String? get _fabLabel => switch (_index) {
        1 => 'مشترى جديد',
        2 => 'بيع جديد',
        3 => 'مصروف جديد',
        4 => 'شريك جديد',
        _ => null,
      };

  void _onFab() {
    final Widget? page = switch (_index) {
      1 => const PurchaseForm(),
      2 => const SaleForm(),
      3 => const ExpenseForm(),
      4 => const PartnerForm(),
      _ => null,
    };
    if (page == null) return;
    Navigator.push<void>(
        context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _index,
            isDense: true,
            dropdownColor: kGold,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            items: List<DropdownMenuItem<int>>.generate(
              _titles.length,
              (int i) => DropdownMenuItem<int>(
                value: i,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(_icons[i], color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(_titles[i],
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            onChanged: (int? v) => setState(() => _index = v ?? 0),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'السعر العالمي للذهب',
            icon: const Icon(Icons.currency_exchange),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const GoldPriceScreen()),
            ),
          ),
          IconButton(
            tooltip: 'الآلة الحاسبة',
            icon: const Icon(Icons.calculate),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const CalculatorScreen()),
            ),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          DashboardScreen(onGoTo: (int i) => setState(() => _index = i)),
          const PurchasesScreen(),
          const SalesScreen(),
          const ExpensesScreen(),
          const PartnersScreen(),
        ],
      ),
      floatingActionButton: _fabLabel == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _onFab,
              icon: const Icon(Icons.add),
              label: Text(_fabLabel!),
              backgroundColor: kGold,
              foregroundColor: Colors.white,
            ),
    );
  }
}
