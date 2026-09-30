class Purchase {
  final String id;
  final DateTime date;
  final int grams, habba, juz, purity;
  final double amount, pendingAmount;
  final String seller, bankAccount, notes;

  Purchase({
    required this.id,
    required this.date,
    required this.grams,
    required this.habba,
    required this.juz,
    required this.purity,
    required this.amount,
    required this.pendingAmount,
    required this.seller,
    required this.bankAccount,
    required this.notes,
  });

  double get weight => grams + habba / 10 + juz / 100;
  String get weightStr => '$grams.$habba.$juz';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'grams': grams,
        'habba': habba,
        'juz': juz,
        'purity': purity,
        'amount': amount,
        'pendingAmount': pendingAmount,
        'seller': seller,
        'bankAccount': bankAccount,
        'notes': notes,
      };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        grams: j['grams'] as int,
        habba: j['habba'] as int,
        juz: j['juz'] as int,
        purity: (j['purity'] as num?)?.toInt() ?? 0,
        amount: (j['amount'] as num).toDouble(),
        pendingAmount: (j['pendingAmount'] as num?)?.toDouble() ?? 0,
        seller: (j['seller'] as String?) ?? '',
        bankAccount: (j['bankAccount'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );

  Purchase copyWith({double? pendingAmount}) => Purchase(
        id: id,
        date: date,
        grams: grams,
        habba: habba,
        juz: juz,
        purity: purity,
        amount: amount,
        pendingAmount: pendingAmount ?? this.pendingAmount,
        seller: seller,
        bankAccount: bankAccount,
        notes: notes,
      );
}

class Sale {
  final String id;
  final DateTime date;
  final int grams, habba, juz, purity;
  final double buyAmount, sellAmount;
  final String buyer, notes;

  Sale({
    required this.id,
    required this.date,
    required this.grams,
    required this.habba,
    required this.juz,
    required this.purity,
    required this.buyAmount,
    required this.sellAmount,
    required this.buyer,
    required this.notes,
  });

  double get weight => grams + habba / 10 + juz / 100;
  double get profit => sellAmount - buyAmount;
  String get weightStr => '$grams.$habba.$juz';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'grams': grams,
        'habba': habba,
        'juz': juz,
        'purity': purity,
        'buyAmount': buyAmount,
        'sellAmount': sellAmount,
        'buyer': buyer,
        'notes': notes,
      };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        grams: j['grams'] as int,
        habba: j['habba'] as int,
        juz: j['juz'] as int,
        purity: (j['purity'] as num?)?.toInt() ?? 0,
        buyAmount: (j['buyAmount'] as num).toDouble(),
        sellAmount: (j['sellAmount'] as num).toDouble(),
        buyer: (j['buyer'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );
}

class Expense {
  final String id;
  final DateTime date;
  final double amount;
  final String category; // فئة مفتوحة (كهرباء، فطور...)
  final String target;   // 'عام' أو اسم شريك
  final String notes;

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.target,
    required this.notes,
  });

  bool get isGeneral => target == 'عام';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'category': category,
        'target': target,
        'notes': notes,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        category: (j['category'] as String?) ?? '',
        target: (j['target'] as String?) ?? 'عام',
        notes: (j['notes'] as String?) ?? '',
      );
}

class Partner {
  final String id;
  final String name;
  final double capital; // رأس المال المدخل

  Partner({
    required this.id,
    required this.name,
    required this.capital,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'capital': capital,
      };

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: j['id'] as String,
        name: j['name'] as String,
        capital: (j['capital'] as num?)?.toDouble() ?? 0,
      );

  Partner copyWith({String? name, double? capital}) => Partner(
        id: id,
        name: name ?? this.name,
        capital: capital ?? this.capital,
      );
}
