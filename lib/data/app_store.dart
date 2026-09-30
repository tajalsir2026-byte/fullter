import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/models.dart';

/// ============================================================
///  مخزن البيانات الموحّد
///  كل الشاشات تقرأ وتكتب من هنا — لذلك أي تعديل يظهر فوراً
///  في كل الشاشات (هذا يحل مشكلة "الشريك الجديد لا يظهر").
/// ============================================================
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  bool loaded = false;
  String? lastError;

  List<Purchase> purchases = <Purchase>[];
  List<Sale> sales = <Sale>[];
  List<Expense> expenses = <Expense>[];
  List<Partner> partners = <Partner>[];

  // ---------------------------------------------------------
  // التحميل والحفظ
  // ---------------------------------------------------------
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    purchases = _decode<Purchase>(
        prefs.getString(StoreKeys.purchases), (Map<String, dynamic> j) => Purchase.fromJson(j));
    sales = _decode<Sale>(
        prefs.getString(StoreKeys.sales), (Map<String, dynamic> j) => Sale.fromJson(j));
    expenses = _decode<Expense>(
        prefs.getString(StoreKeys.expenses), (Map<String, dynamic> j) => Expense.fromJson(j));
    partners = _decode<Partner>(
        prefs.getString(StoreKeys.partners), (Map<String, dynamic> j) => Partner.fromJson(j));
    _sortAll();
    loaded = true;
    notifyListeners();
  }

  List<T> _decode<T>(String? raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      lastError = 'تعذّر قراءة البيانات المحفوظة: $e';
      debugPrint(lastError);
      return <T>[];
    }
  }

  void _sortAll() {
    purchases.sort((Purchase a, Purchase b) => b.date.compareTo(a.date));
    sales.sort((Sale a, Sale b) => b.date.compareTo(a.date));
    expenses.sort((Expense a, Expense b) => b.date.compareTo(a.date));
    partners.sort((Partner a, Partner b) => a.name.compareTo(b.name));
  }

  /// يحفظ كل شيء. يرجع false إذا فشل الحفظ (تُعرض رسالة للمستخدم)
  Future<bool> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(StoreKeys.purchases,
          jsonEncode(purchases.map((Purchase e) => e.toJson()).toList()));
      await prefs.setString(StoreKeys.sales,
          jsonEncode(sales.map((Sale e) => e.toJson()).toList()));
      await prefs.setString(StoreKeys.expenses,
          jsonEncode(expenses.map((Expense e) => e.toJson()).toList()));
      await prefs.setString(StoreKeys.partners,
          jsonEncode(partners.map((Partner e) => e.toJson()).toList()));
      lastError = null;
      return true;
    } catch (e) {
      lastError = 'فشل حفظ البيانات: $e';
      debugPrint(lastError);
      return false;
    }
  }

  Future<bool> _commit() async {
    _sortAll();
    notifyListeners();
    return _persist();
  }

  // ---------------------------------------------------------
  // المشتريات
  // ---------------------------------------------------------
  Future<bool> addPurchase(Purchase p) async {
    purchases.add(p);
    return _commit();
  }

  Future<bool> updatePurchase(Purchase p) async {
    final int i = purchases.indexWhere((Purchase x) => x.id == p.id);
    if (i >= 0) purchases[i] = p;
    return _commit();
  }

  Future<bool> deletePurchase(String id) async {
    purchases.removeWhere((Purchase x) => x.id == id);
    // فك ارتباط المبيعات المرتبطة بهذا المشترى بدل حذفها
    for (int i = 0; i < sales.length; i++) {
      if (sales[i].purchaseId == id) {
        sales[i] = Sale(
          id: sales[i].id,
          date: sales[i].date,
          units: sales[i].units,
          purity: sales[i].purity,
          buyAmount: sales[i].buyAmount,
          sellAmount: sales[i].sellAmount,
          buyer: sales[i].buyer,
          notes: sales[i].notes,
        );
      }
    }
    return _commit();
  }

  /// تسديد جزء من المتبقي مع تسجيل الدفعة في السجل
  Future<bool> payPurchase(String id, double amount, {String note = ''}) async {
    final int i = purchases.indexWhere((Purchase x) => x.id == id);
    if (i < 0 || amount <= 0) return false;
    final Purchase p = purchases[i];
    final double newPending =
        (p.pendingAmount - amount).clamp(0.0, double.infinity);
    purchases[i] = p.copyWith(
      pendingAmount: newPending,
      payments: <Payment>[
        ...p.payments,
        Payment(id: newId(), date: DateTime.now(), amount: amount, note: note),
      ],
    );
    return _commit();
  }

  // ---------------------------------------------------------
  // المبيعات
  // ---------------------------------------------------------
  Future<bool> addSale(Sale s) async {
    sales.add(s);
    return _commit();
  }

  Future<bool> updateSale(Sale s) async {
    final int i = sales.indexWhere((Sale x) => x.id == s.id);
    if (i >= 0) sales[i] = s;
    return _commit();
  }

  Future<bool> deleteSale(String id) async {
    sales.removeWhere((Sale x) => x.id == id);
    return _commit();
  }

  // ---------------------------------------------------------
  // المصروفات
  // ---------------------------------------------------------
  Future<bool> addExpense(Expense e) async {
    expenses.add(e);
    return _commit();
  }

  Future<bool> updateExpense(Expense e) async {
    final int i = expenses.indexWhere((Expense x) => x.id == e.id);
    if (i >= 0) expenses[i] = e;
    return _commit();
  }

  Future<bool> deleteExpense(String id) async {
    expenses.removeWhere((Expense x) => x.id == id);
    return _commit();
  }

  /// كل الفئات المستخدمة + الفئات الافتراضية
  List<String> get allCategories {
    final Set<String> s = <String>{...kDefaultCategories};
    for (final Expense e in expenses) {
      if (e.category.trim().isNotEmpty) s.add(e.category.trim());
    }
    final List<String> list = s.toList()..sort();
    return list;
  }

  // ---------------------------------------------------------
  // الشركاء
  // ---------------------------------------------------------
  Future<bool> addPartner(Partner p) async {
    partners.add(p);
    return _commit();
  }

  Future<bool> updatePartner(Partner p) async {
    final int i = partners.indexWhere((Partner x) => x.id == p.id);
    if (i >= 0) {
      final String oldName = partners[i].name;
      partners[i] = p;
      // لو تغيّر الاسم، حدّث المصروفات المرتبطة به
      if (oldName != p.name) {
        for (int k = 0; k < expenses.length; k++) {
          if (expenses[k].target == oldName) {
            expenses[k] = expenses[k].copyWith(target: p.name, name: p.name);
          }
        }
      }
    }
    return _commit();
  }

  Future<bool> deletePartner(String id) async {
    final int i = partners.indexWhere((Partner x) => x.id == id);
    if (i < 0) return false;
    final String name = partners[i].name;
    partners.removeAt(i);
    // المصروفات الخاصة به تتحوّل إلى "عام" حتى لا تضيع من الحسابات
    for (int k = 0; k < expenses.length; k++) {
      if (expenses[k].target == name) {
        expenses[k] = expenses[k].copyWith(target: kGeneral);
      }
    }
    return _commit();
  }

  List<String> get partnerNames =>
      partners.map((Partner p) => p.name).where((String n) => n.isNotEmpty).toList();

  // ============================================================
  //  الحسابات المالية (قلب التطبيق)
  // ============================================================

  // --- المشتريات ---
  int get purchasedUnits =>
      purchases.fold<int>(0, (int s, Purchase p) => s + p.units);
  double get purchasedAmount =>
      purchases.fold<double>(0, (double s, Purchase p) => s + p.amount);
  double get totalPending =>
      purchases.fold<double>(0, (double s, Purchase p) => s + p.pendingAmount);
  double get totalPaidToSellers => purchasedAmount - totalPending;

  // --- المبيعات ---
  int get soldUnits => sales.fold<int>(0, (int s, Sale x) => s + x.units);
  double get salesRevenue =>
      sales.fold<double>(0, (double s, Sale x) => s + x.sellAmount);
  double get salesCost =>
      sales.fold<double>(0, (double s, Sale x) => s + x.buyAmount);
  double get grossProfit => salesRevenue - salesCost;

  // --- المخزون ---
  int get inventoryUnits => purchasedUnits - soldUnits;

  /// متوسط تكلفة الجزء الواحد لكل المشتريات
  double get avgCostPerUnit =>
      purchasedUnits == 0 ? 0 : purchasedAmount / purchasedUnits;
  double get avgCostPerGram => avgCostPerUnit * kUnitsPerGram;

  /// القيمة التقديرية للمخزون المتبقي (بمتوسط التكلفة)
  double get inventoryValue => inventoryUnits * avgCostPerUnit;

  /// البحث عن مشترى بالمعرّف
  Purchase? purchaseById(String? id) {
    if (id == null) return null;
    for (final Purchase p in purchases) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// الوزن المباع من مشترى معيّن
  int soldUnitsOf(String purchaseId) => sales
      .where((Sale s) => s.purchaseId == purchaseId)
      .fold<int>(0, (int s, Sale x) => s + x.units);

  /// المتبقي (غير المباع) من مشترى معيّن
  int remainingUnitsOf(Purchase p) => p.units - soldUnitsOf(p.id);

  /// المشتريات التي ما زال فيها رصيد للبيع
  List<Purchase> get purchasesWithStock =>
      purchases.where((Purchase p) => remainingUnitsOf(p) > 0).toList();

  // --- المصروفات ---
  double get totalExpenses =>
      expenses.fold<double>(0, (double s, Expense e) => s + e.amount);
  double get generalExpenses => expenses
      .where((Expense e) => e.isGeneral)
      .fold<double>(0, (double s, Expense e) => s + e.amount);
  double get privateExpenses => totalExpenses - generalExpenses;

  double privateExpensesOf(String partnerName) => expenses
      .where((Expense e) => e.target == partnerName)
      .fold<double>(0, (double s, Expense e) => s + e.amount);

  // --- النتيجة ---
  /// الربح الصافي = ربح المبيعات − المصروفات العامة
  /// (المصروفات الخاصة لا تُخصم هنا لأنها تُخصم من حساب الشريك نفسه)
  double get netProfit => grossProfit - generalExpenses;

  // --- رأس المال والشركاء ---
  double get totalCapital =>
      partners.fold<double>(0, (double s, Partner p) => s + p.capital);

  double sharePctOf(Partner p) =>
      totalCapital == 0 ? 0 : p.capital / totalCapital;

  double profitShareOf(Partner p) => sharePctOf(p) * netProfit;

  /// صافي مستحقات الشريك = رأس المال + حصته من الربح − مصروفاته الخاصة
  double netForPartner(Partner p) =>
      p.capital + profitShareOf(p) - privateExpensesOf(p.name);

  // --- النقدية التقديرية ---
  /// نقد داخل + رأس مال − ما دُفع للبائعين − المصروفات
  double get estimatedCash =>
      totalCapital + salesRevenue - totalPaidToSellers - totalExpenses;

  // ============================================================
  //  النسخ الاحتياطي
  // ============================================================
  Map<String, dynamic> exportMap() => <String, dynamic>{
        'app': 'gold_accounts',
        'version': kAppVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'purchases': purchases.map((Purchase e) => e.toJson()).toList(),
        'sales': sales.map((Sale e) => e.toJson()).toList(),
        'expenses': expenses.map((Expense e) => e.toJson()).toList(),
        'partners': partners.map((Partner e) => e.toJson()).toList(),
      };

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(exportMap());

  /// استعادة نسخة احتياطية.
  /// merge = false → استبدال كامل، merge = true → دمج مع تجاهل المكرر
  Future<String> importJson(String raw, {bool merge = false}) async {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return 'الملف غير صالح (ليس نسخة احتياطية)';
      final Map<String, dynamic> j = Map<String, dynamic>.from(decoded);

      List<T> read<T>(String key, T Function(Map<String, dynamic>) f) =>
          (j[key] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic e) => f(Map<String, dynamic>.from(e as Map)))
              .toList();

      final List<Purchase> np = read<Purchase>('purchases', Purchase.fromJson);
      final List<Sale> ns = read<Sale>('sales', Sale.fromJson);
      final List<Expense> ne = read<Expense>('expenses', Expense.fromJson);
      final List<Partner> nr = read<Partner>('partners', Partner.fromJson);

      if (merge) {
        void mergeIn<T>(List<T> target, List<T> src, String Function(T) id) {
          final Set<String> ids = target.map(id).toSet();
          for (final T item in src) {
            if (!ids.contains(id(item))) target.add(item);
          }
        }

        mergeIn<Purchase>(purchases, np, (Purchase x) => x.id);
        mergeIn<Sale>(sales, ns, (Sale x) => x.id);
        mergeIn<Expense>(expenses, ne, (Expense x) => x.id);
        mergeIn<Partner>(partners, nr, (Partner x) => x.id);
      } else {
        purchases = np;
        sales = ns;
        expenses = ne;
        partners = nr;
      }

      final bool ok = await _commit();
      if (!ok) return 'تمت القراءة لكن فشل الحفظ: $lastError';
      return 'تمت الاستعادة: ${np.length} مشترى، ${ns.length} بيع، '
          '${ne.length} مصروف، ${nr.length} شريك';
    } catch (e) {
      return 'فشل قراءة الملف: $e';
    }
  }

  /// حذف كل البيانات (لا يحذف كلمة السر)
  Future<bool> wipeAll() async {
    purchases = <Purchase>[];
    sales = <Sale>[];
    expenses = <Expense>[];
    partners = <Partner>[];
    return _commit();
  }
}
