import '../core/constants.dart';
import '../core/format.dart';

/// ============================================================
///  النماذج (Models)
///  كل fromJson متسامح مع البيانات القديمة (نسخة 3 وما قبلها)
/// ============================================================

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _asString(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

DateTime _asDate(dynamic v) =>
    DateTime.tryParse(_asString(v)) ?? DateTime.now();

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// يقرأ الوزن سواء كان مخزّناً بالنظام الجديد (units)
/// أو بالنظام القديم (grams/habba/juz)
int _readUnits(Map<String, dynamic> j) {
  if (j['units'] != null) return _asInt(j['units']);
  return weightToUnits(_asInt(j['grams']), _asInt(j['habba']), _asInt(j['juz']));
}

// ============================================================
// دفعة سداد (لسجل تسديد المتبقي)
// ============================================================
class Payment {
  final String id;
  final DateTime date;
  final double amount;
  final String note;

  Payment({
    required this.id,
    required this.date,
    required this.amount,
    this.note = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'note': note,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: _asString(j['id'], newId()),
        date: _asDate(j['date']),
        amount: _asDouble(j['amount']),
        note: _asString(j['note']),
      );
}

// ============================================================
// مشترى
// ============================================================
class Purchase {
  final String id;
  final DateTime date;
  final int units; // الوزن بالأجزاء
  final int purity;
  final double amount; // إجمالي قيمة المشترى
  final double pendingAmount; // المتبقي للبائع
  final String seller;
  final String bankAccount;
  final String notes;
  final List<Payment> payments;

  Purchase({
    required this.id,
    required this.date,
    required this.units,
    required this.purity,
    required this.amount,
    required this.pendingAmount,
    this.seller = '',
    this.bankAccount = '',
    this.notes = '',
    List<Payment>? payments,
  }) : payments = payments ?? <Payment>[];

  int get grams => units ~/ kUnitsPerGram;
  int get habba => (units % kUnitsPerGram) ~/ kUnitsPerHabba;
  int get juz => units % kUnitsPerHabba;
  String get weightStr => unitsToWeight(units);

  double get paidAmount => amount - pendingAmount;

  /// تكلفة الجزء الواحد (تُستخدم لحساب تكلفة البيع تلقائياً)
  double get costPerUnit => units == 0 ? 0 : amount / units;

  /// تكلفة الجرام
  double get costPerGram => costPerUnit * kUnitsPerGram;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'units': units,
        // نكتب الحقول القديمة أيضاً حتى لا تنكسر النسخ الأقدم
        'grams': grams,
        'habba': habba,
        'juz': juz,
        'purity': purity,
        'amount': amount,
        'pendingAmount': pendingAmount,
        'seller': seller,
        'bankAccount': bankAccount,
        'notes': notes,
        'payments': payments.map((Payment p) => p.toJson()).toList(),
      };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: _asString(j['id'], newId()),
        date: _asDate(j['date']),
        units: _readUnits(j),
        purity: _asInt(j['purity']),
        amount: _asDouble(j['amount']),
        pendingAmount: _asDouble(j['pendingAmount']),
        seller: _asString(j['seller']),
        bankAccount: _asString(j['bankAccount']),
        notes: _asString(j['notes']),
        payments: (j['payments'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => Payment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Purchase copyWith({
    DateTime? date,
    int? units,
    int? purity,
    double? amount,
    double? pendingAmount,
    String? seller,
    String? bankAccount,
    String? notes,
    List<Payment>? payments,
  }) =>
      Purchase(
        id: id,
        date: date ?? this.date,
        units: units ?? this.units,
        purity: purity ?? this.purity,
        amount: amount ?? this.amount,
        pendingAmount: pendingAmount ?? this.pendingAmount,
        seller: seller ?? this.seller,
        bankAccount: bankAccount ?? this.bankAccount,
        notes: notes ?? this.notes,
        payments: payments ?? this.payments,
      );
}

// ============================================================
// بيع
// ============================================================
class Sale {
  final String id;
  final DateTime date;
  final int units;
  final int purity;
  final double buyAmount; // التكلفة
  final double sellAmount; // مبلغ البيع
  final String buyer;
  final String notes;

  /// ربط اختياري بمشترى معيّن (لخصم المخزون وحساب التكلفة تلقائياً)
  final String? purchaseId;

  Sale({
    required this.id,
    required this.date,
    required this.units,
    required this.purity,
    required this.buyAmount,
    required this.sellAmount,
    this.buyer = '',
    this.notes = '',
    this.purchaseId,
  });

  int get grams => units ~/ kUnitsPerGram;
  int get habba => (units % kUnitsPerGram) ~/ kUnitsPerHabba;
  int get juz => units % kUnitsPerHabba;
  String get weightStr => unitsToWeight(units);
  double get profit => sellAmount - buyAmount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'units': units,
        'grams': grams,
        'habba': habba,
        'juz': juz,
        'purity': purity,
        'buyAmount': buyAmount,
        'sellAmount': sellAmount,
        'buyer': buyer,
        'notes': notes,
        'purchaseId': purchaseId,
      };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: _asString(j['id'], newId()),
        date: _asDate(j['date']),
        units: _readUnits(j),
        purity: _asInt(j['purity']),
        buyAmount: _asDouble(j['buyAmount']),
        sellAmount: _asDouble(j['sellAmount']),
        buyer: _asString(j['buyer']),
        notes: _asString(j['notes']),
        purchaseId: j['purchaseId'] == null ? null : _asString(j['purchaseId']),
      );
}

// ============================================================
// مصروف
// ============================================================
class Expense {
  final String id;
  final DateTime date;
  final double amount;
  final String category; // كهرباء، فطور، ...
  final String target; // 'عام' أو اسم شريك
  final String name; // اسم صاحب/مستلم المصروف (حقل صريح الآن)
  final String notes;

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.target,
    this.name = '',
    this.notes = '',
  });

  bool get isGeneral => target == kGeneral;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'category': category,
        'target': target,
        'name': name,
        'notes': notes,
      };

  factory Expense.fromJson(Map<String, dynamic> j) {
    final String target = _asString(j['target'], kGeneral);
    String notes = _asString(j['notes']);
    String name = _asString(j['name']);

    // ترحيل البيانات القديمة: الاسم كان مدسوساً في الملاحظات ⟦الاسم⟧الملاحظة
    if (name.isEmpty && notes.startsWith('⟦') && notes.contains('⟧')) {
      final int end = notes.indexOf('⟧');
      name = notes.substring(1, end);
      notes = notes.substring(end + 1);
    }
    if (name.isEmpty && target != kGeneral) name = target;

    return Expense(
      id: _asString(j['id'], newId()),
      date: _asDate(j['date']),
      amount: _asDouble(j['amount']),
      category: _asString(j['category']),
      target: target.isEmpty ? kGeneral : target,
      name: name,
      notes: notes,
    );
  }

  Expense copyWith({
    DateTime? date,
    double? amount,
    String? category,
    String? target,
    String? name,
    String? notes,
  }) =>
      Expense(
        id: id,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        target: target ?? this.target,
        name: name ?? this.name,
        notes: notes ?? this.notes,
      );
}

// ============================================================
// شريك
// ============================================================
class Partner {
  final String id;
  final String name;
  final double capital; // رأس المال المدخل
  final String phone;
  final String notes;

  Partner({
    required this.id,
    required this.name,
    required this.capital,
    this.phone = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'capital': capital,
        'phone': phone,
        'notes': notes,
      };

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: _asString(j['id'], newId()),
        name: _asString(j['name']),
        capital: _asDouble(j['capital']),
        phone: _asString(j['phone']),
        notes: _asString(j['notes']),
      );

  Partner copyWith({
    String? name,
    double? capital,
    String? phone,
    String? notes,
  }) =>
      Partner(
        id: id,
        name: name ?? this.name,
        capital: capital ?? this.capital,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
      );
}
