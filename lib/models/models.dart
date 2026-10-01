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

/// وقت آخر تعديل: لو السجل قديم (قبل المزامنة) نستخدم تاريخ العملية،
/// وإن لم يوجد نستخدم أقدم وقت ممكن حتى لا يطغى القديم على الجديد عند الدمج
DateTime _asUpdatedAt(Map<String, dynamic> j) {
  final dynamic v = j['updatedAt'] ?? j['date'];
  if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(v.toString()) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

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

  /// وقت آخر تعديل — تستخدمه المزامنة لمعرفة أي نسخة أحدث
  final DateTime updatedAt;

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
    DateTime? updatedAt,
  })  : payments = payments ?? <Payment>[],
        updatedAt = updatedAt ?? DateTime.now();

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
        'updatedAt': updatedAt.toIso8601String(),
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
        updatedAt: _asUpdatedAt(j),
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
    DateTime? updatedAt,
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
        updatedAt: updatedAt,
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

  final DateTime updatedAt;

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
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

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
        'updatedAt': updatedAt.toIso8601String(),
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
        updatedAt: _asUpdatedAt(j),
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
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.target,
    this.name = '',
    this.notes = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isGeneral => target == kGeneral;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'category': category,
        'target': target,
        'name': name,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
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
      updatedAt: _asUpdatedAt(j),
    );
  }

  Expense copyWith({
    DateTime? date,
    double? amount,
    String? category,
    String? target,
    String? name,
    String? notes,
    DateTime? updatedAt,
  }) =>
      Expense(
        id: id,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        target: target ?? this.target,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        updatedAt: updatedAt,
      );
}

// ============================================================
// شريك
// ============================================================
class Partner {
  final String id;
  final String name;
  final double capital; // رأس المال المدخل
  final double profitPercent; // نسبة الربح اليدوية (مستقلة عن رأس المال)
  final String phone;
  final String notes;
  final DateTime updatedAt;

  Partner({
    required this.id,
    required this.name,
    required this.capital,
    this.profitPercent = 0,
    this.phone = '',
    this.notes = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'capital': capital,
        'profitPercent': profitPercent,
        'phone': phone,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: _asString(j['id'], newId()),
        name: _asString(j['name']),
        capital: _asDouble(j['capital']),
        profitPercent: _asDouble(j['profitPercent']),
        phone: _asString(j['phone']),
        notes: _asString(j['notes']),
        updatedAt: _asUpdatedAt(j),
      );

  Partner copyWith({
    String? name,
    double? capital,
    double? profitPercent,
    String? phone,
    String? notes,
    DateTime? updatedAt,
  }) =>
      Partner(
        id: id,
        name: name ?? this.name,
        capital: capital ?? this.capital,
        profitPercent: profitPercent ?? this.profitPercent,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
        updatedAt: updatedAt,
      );
}
