import 'package:flutter_test/flutter_test.dart';
import 'package:gold_accounts/models/models.dart';

void main() {
  group('ترحيل البيانات القديمة', () {
    test('قراءة مشترى بالنظام القديم (grams/habba/juz)', () {
      final Purchase p = Purchase.fromJson(<String, dynamic>{
        'id': '1',
        'date': '2026-09-01T10:00:00.000',
        'grams': 10,
        'habba': 2,
        'juz': 5,
        'purity': 21,
        'amount': 1000000,
        'pendingAmount': 250000,
        'seller': 'محمد',
      });
      expect(p.units, 1025);
      expect(p.weightStr, '10.2.5');
      expect(p.paidAmount, 750000);
    });

    test('قراءة مشترى بالنظام الجديد (units)', () {
      final Purchase p = Purchase.fromJson(<String, dynamic>{
        'id': '2',
        'date': '2026-09-01T10:00:00.000',
        'units': 530,
        'amount': 500000,
        'pendingAmount': 0,
      });
      expect(p.weightStr, '5.3.0');
      expect(p.costPerUnit, 500000 / 530);
    });

    test('استخراج اسم المصروف من حيلة ⟦⟧ القديمة', () {
      final Expense e = Expense.fromJson(<String, dynamic>{
        'id': '3',
        'date': '2026-09-01T10:00:00.000',
        'amount': 5000,
        'category': 'فطور',
        'target': 'عام',
        'notes': '⟦عثمان⟧فطور الصباح',
      });
      expect(e.name, 'عثمان');
      expect(e.notes, 'فطور الصباح');
      expect(e.isGeneral, true);
    });

    test('الحقول الناقصة لا تُسقط السجل', () {
      final Sale s = Sale.fromJson(<String, dynamic>{
        'id': '4',
        'date': '2026-09-01T10:00:00.000',
        'grams': 1,
        'buyAmount': 100,
        'sellAmount': 150,
      });
      expect(s.units, 100);
      expect(s.profit, 50);
      expect(s.buyer, '');
      expect(s.purchaseId, null);
    });

    test('دورة كاملة toJson ثم fromJson', () {
      final Purchase p = Purchase(
        id: '5',
        date: DateTime(2026, 9, 30),
        units: 1234,
        purity: 21,
        amount: 900000,
        pendingAmount: 100000,
        seller: 'أحمد',
        payments: <Payment>[
          Payment(id: 'p1', date: DateTime(2026, 9, 30), amount: 50000),
        ],
      );
      final Purchase back = Purchase.fromJson(p.toJson());
      expect(back.units, p.units);
      expect(back.amount, p.amount);
      expect(back.payments.length, 1);
      expect(back.payments.first.amount, 50000);
    });
  });
}
