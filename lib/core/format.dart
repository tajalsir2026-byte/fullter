import 'constants.dart';

/// ============================================================
///  تنسيق الأرقام والأوزان
///  ملاحظة مهمة: الوزن يُخزَّن دائماً كعدد صحيح من "الأجزاء"
///  (1 جرام = 10 حبة = 100 جزء) حتى لا تحدث أخطاء الكسور العشرية.
/// ============================================================

/// 1234567 -> "1,234,567"
String fmtNum(num n) {
  final bool neg = n < 0;
  final String s = n.abs().round().toString();
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}$buf';
}

/// مبلغ مع العملة: "1,200 ج.س"
String fmtMoney(num n) => '${fmtNum(n)} $kCurrency';

/// تحويل (جرام، حبة، جزء) إلى عدد الأجزاء الصحيح
int weightToUnits(int grams, int habba, int juz) =>
    grams * kUnitsPerGram + habba * kUnitsPerHabba + juz;

/// تحويل عدد الأجزاء إلى نص "جرام.حبة.جزء"
/// مثال: 1025 -> "10.2.5"
String unitsToWeight(int units) {
  final bool neg = units < 0;
  final int u = units.abs();
  final int g = u ~/ kUnitsPerGram;
  final int h = (u % kUnitsPerGram) ~/ kUnitsPerHabba;
  final int j = u % kUnitsPerHabba;
  return '${neg ? '-' : ''}$g.$h.$j';
}

/// الوزن بالجرام كرقم عشري (للحسابات المالية فقط، لا للعرض)
double unitsToGrams(int units) => units / kUnitsPerGram;

/// 30/9/2026
String dateStr(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// 2026-09-30 (للترتيب وأسماء الملفات)
String dateSortStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const List<String> _arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// 30 سبتمبر 2026
String dateLongStr(DateTime d) => '${d.day} ${_arMonths[d.month - 1]} ${d.year}';

/// يحوّل الأرقام العربية-الهندية (٠١٢٣) إلى إنجليزية ويزيل الفواصل
/// حتى لو كتب المستخدم "١٢,٥٠٠" يُقرأ 12500
String normalizeDigits(String input) {
  const String ar = '٠١٢٣٤٥٦٧٨٩';
  const String fa = '۰۱۲۳۴۵۶۷۸۹';
  final StringBuffer out = StringBuffer();
  for (final int code in input.runes) {
    final String ch = String.fromCharCode(code);
    final int ai = ar.indexOf(ch);
    final int fi = fa.indexOf(ch);
    if (ai >= 0) {
      out.write(ai);
    } else if (fi >= 0) {
      out.write(fi);
    } else if (ch != ',' && ch != '٬' && ch != ' ') {
      out.write(ch);
    }
  }
  return out.toString().trim();
}

/// قراءة رقم عشري من نص المستخدم (يتحمّل الأرقام العربية والفواصل)
double parseNum(String input) => double.tryParse(normalizeDigits(input)) ?? 0;

/// قراءة عدد صحيح من نص المستخدم
int parseInt(String input) => int.tryParse(normalizeDigits(input)) ?? 0;
