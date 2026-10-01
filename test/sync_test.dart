import 'package:flutter_test/flutter_test.dart';
import 'package:gold_accounts/data/sync_merge.dart';

Map<String, dynamic> rec(String id, String updatedAt, {double amount = 100}) =>
    <String, dynamic>{
      'id': id,
      'date': '2026-10-01T10:00:00.000Z',
      'units': 100,
      'amount': amount,
      'pendingAmount': 0,
      'updatedAt': updatedAt,
    };

Map<String, dynamic> payload({
  List<Map<String, dynamic>>? purchases,
  List<Map<String, dynamic>>? sales,
  Map<String, String>? deleted,
}) =>
    <String, dynamic>{
      'purchases': purchases ?? <Map<String, dynamic>>[],
      'sales': sales ?? <Map<String, dynamic>>[],
      'expenses': <Map<String, dynamic>>[],
      'partners': <Map<String, dynamic>>[],
      'deleted': deleted ?? <String, String>{},
    };

List<String> ids(Map<String, dynamic> p, String key) =>
    (p[key] as List<dynamic>)
        .map((dynamic e) => (e as Map<String, dynamic>)['id'].toString())
        .toList()
      ..sort();

void main() {
  group('دمج بيانات جهازين', () {
    test('اتحاد السجلات: كل جهاز يأخذ ما عند الآخر', () {
      final Map<String, dynamic> a = payload(
          purchases: <Map<String, dynamic>>[rec('1', '2026-10-01T10:00:00Z')]);
      final Map<String, dynamic> b = payload(
          purchases: <Map<String, dynamic>>[rec('2', '2026-10-01T11:00:00Z')]);

      expect(ids(mergePayloads(a, b), 'purchases'), <String>['1', '2']);
      // الدمج متماثل: نفس النتيجة من الجهة الأخرى
      expect(ids(mergePayloads(b, a), 'purchases'), <String>['1', '2']);
    });

    test('نفس السجل عُدّل في الجهازين: الأحدث يفوز', () {
      final Map<String, dynamic> a = payload(purchases: <Map<String, dynamic>>[
        rec('1', '2026-10-01T10:00:00Z', amount: 500)
      ]);
      final Map<String, dynamic> b = payload(purchases: <Map<String, dynamic>>[
        rec('1', '2026-10-01T12:00:00Z', amount: 900)
      ]);

      final Map<String, dynamic> m = mergePayloads(a, b);
      final List<dynamic> rows = m['purchases'] as List<dynamic>;
      expect(rows.length, 1);
      expect((rows.first as Map<String, dynamic>)['amount'], 900);
    });

    test('الحذف في جهاز ينتقل للجهاز الآخر', () {
      final Map<String, dynamic> hasIt = payload(
          purchases: <Map<String, dynamic>>[rec('1', '2026-10-01T10:00:00Z')]);
      final Map<String, dynamic> deletedIt = payload(
        deleted: <String, String>{'1': '2026-10-01T11:00:00Z'},
      );

      expect((mergePayloads(hasIt, deletedIt)['purchases'] as List<dynamic>),
          isEmpty);
      expect((mergePayloads(deletedIt, hasIt)['purchases'] as List<dynamic>),
          isEmpty);
    });

    test('التعديل بعد الحذف يُرجع السجل (التعديل أحدث)', () {
      final Map<String, dynamic> edited = payload(
          purchases: <Map<String, dynamic>>[rec('1', '2026-10-01T15:00:00Z')]);
      final Map<String, dynamic> deletedOld = payload(
        deleted: <String, String>{'1': '2026-10-01T11:00:00Z'},
      );

      final Map<String, dynamic> m = mergePayloads(edited, deletedOld);
      expect((m['purchases'] as List<dynamic>).length, 1);
      expect((m['deleted'] as Map<String, String>).containsKey('1'), false);
    });

    test('علامات الحذف تُدمج وتبقى للجولة القادمة', () {
      final Map<String, dynamic> a =
          payload(deleted: <String, String>{'1': '2026-10-01T11:00:00Z'});
      final Map<String, dynamic> b =
          payload(deleted: <String, String>{'2': '2026-10-01T12:00:00Z'});
      final Map<String, String> d =
          mergePayloads(a, b)['deleted'] as Map<String, String>;
      expect(d.keys.toList()..sort(), <String>['1', '2']);
    });

    test('بيانات فارغة أو ناقصة لا تُسقط التطبيق', () {
      final Map<String, dynamic> m =
          mergePayloads(<String, dynamic>{}, <String, dynamic>{});
      for (final String k in kSyncLists) {
        expect(m[k], isEmpty);
      }
      final Map<String, dynamic> m2 = mergePayloads(
        <String, dynamic>{'purchases': 'نص غلط', 'deleted': 5},
        payload(purchases: <Map<String, dynamic>>[rec('1', '2026-10-01T10:00:00Z')]),
      );
      expect(ids(m2, 'purchases'), <String>['1']);
    });

    test('تنظيف علامات الحذف القديمة', () {
      final DateTime now = DateTime.utc(2026, 10, 1);
      final Map<String, String> d = pruneTombstones(<String, String>{
        'قديم': '2026-01-01T00:00:00Z',
        'جديد': '2026-09-25T00:00:00Z',
      }, now: now);
      expect(d.containsKey('قديم'), false);
      expect(d.containsKey('جديد'), true);
    });

    test('المزامنة المتكررة لا تغيّر النتيجة (idempotent)', () {
      final Map<String, dynamic> a = payload(
          purchases: <Map<String, dynamic>>[rec('1', '2026-10-01T10:00:00Z')],
          deleted: <String, String>{'9': '2026-09-30T10:00:00Z'});
      final Map<String, dynamic> b = payload(
          purchases: <Map<String, dynamic>>[rec('2', '2026-10-01T11:00:00Z')]);

      final Map<String, dynamic> once = mergePayloads(a, b);
      final Map<String, dynamic> twice = mergePayloads(once, once);
      expect(ids(twice, 'purchases'), ids(once, 'purchases'));
      expect((twice['deleted'] as Map<String, String>).keys.toList(),
          (once['deleted'] as Map<String, String>).keys.toList());
    });
  });
}
