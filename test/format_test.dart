import 'package:flutter_test/flutter_test.dart';
import 'package:gold_accounts/core/format.dart';

void main() {
  group('حساب الأوزان بالأعداد الصحيحة', () {
    test('التحويل بين (جرام.حبة.جزء) والأجزاء', () {
      expect(weightToUnits(10, 2, 5), 1025);
      expect(unitsToWeight(1025), '10.2.5');
      expect(unitsToWeight(0), '0.0.0');
      expect(unitsToWeight(9), '0.0.9');
      expect(unitsToWeight(100), '1.0.0');
    });

    test('الترحيل: 5 حبة + 7 حبة = 1 جرام و2 حبة', () {
      final int total = weightToUnits(0, 5, 0) + weightToUnits(0, 7, 0);
      expect(unitsToWeight(total), '1.2.0');
    });

    test('لا يظهر الرقم 10 في خانة الحبة أو الجزء أبداً', () {
      // هذه الحالة كانت تنتج "0.0.10" في النسخة القديمة بسبب الكسور العشرية
      final int total = weightToUnits(0, 1, 0) + weightToUnits(0, 0, 9);
      expect(unitsToWeight(total), '0.1.9');

      for (int a = 0; a < 10; a++) {
        for (int b = 0; b < 10; b++) {
          for (int c = 0; c < 10; c++) {
            for (int d = 0; d < 10; d++) {
              final int t = weightToUnits(0, a, b) + weightToUnits(0, c, d);
              final List<String> parts = unitsToWeight(t).split('.');
              expect(int.parse(parts[1]) < 10, true);
              expect(int.parse(parts[2]) < 10, true);
            }
          }
        }
      }
    });

    test('جمع 1000 عملية يبقى دقيقاً', () {
      int total = 0;
      for (int i = 0; i < 1000; i++) {
        total += weightToUnits(0, 0, 1); // جزء واحد لكل عملية
      }
      expect(total, 1000);
      expect(unitsToWeight(total), '10.0.0');
    });

    test('الوزن السالب', () {
      expect(unitsToWeight(-125), '-1.2.5');
    });
  });

  group('تنسيق الأرقام', () {
    test('فواصل الآلاف', () {
      expect(fmtNum(1234567), '1,234,567');
      expect(fmtNum(0), '0');
      expect(fmtNum(-2500), '-2,500');
      expect(fmtNum(999), '999');
    });

    test('قراءة الأرقام العربية والفواصل', () {
      expect(parseNum('١٢٥٠٠'), 12500);
      expect(parseNum('12,500'), 12500);
      expect(parseNum('  1500  '), 1500);
      expect(parseNum('كلام'), 0);
      expect(parseInt('٢١'), 21);
    });
  });
}
