import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../widgets/form_fields.dart';

/// ============================================================
///  الآلة الحاسبة
///  ١) حاسبة عادية: جمع، طرح، ضرب، قسمة، نسبة %، أقواس
///  ٢) حاسبة الذهب: الوزن (جرام/حبة/جزء) × سعر الجرام والعكس
/// ============================================================

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الآلة الحاسبة'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.calculate_outlined), text: 'حاسبة عادية'),
            Tab(icon: Icon(Icons.monetization_on_outlined), text: 'حاسبة الذهب'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const <Widget>[_BasicCalc(), _GoldCalc()],
      ),
    );
  }
}

// ============================================================
//  الحاسبة العادية
// ============================================================

bool _isNumChar(String c) =>
    c.isNotEmpty &&
    ((c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) || c == '.');

class _BasicCalc extends StatefulWidget {
  const _BasicCalc();

  @override
  State<_BasicCalc> createState() => _BasicCalcState();
}

class _BasicCalcState extends State<_BasicCalc>
    with AutomaticKeepAliveClientMixin {
  String _expr = '';
  String _lastLine = '';
  bool _justEvaluated = false;

  @override
  bool get wantKeepAlive => true;

  void _refresh() => setState(() {});

  // ---------- محرّك الحساب ----------

  double? _tryEval(String s) {
    if (s.isEmpty) return null;
    try {
      final _Parser p = _Parser(s);
      final double v = p.expression();
      if (!p.eof || v.isNaN || v.isInfinite) return null;
      return v;
    } on FormatException {
      return null;
    }
  }

  /// تنسيق النتيجة: إزالة ضجيج الفاصلة العائمة + فواصل آلاف اختيارية
  String _fmt(double v, {bool group = true}) {
    final double r = double.parse(v.toStringAsPrecision(12));
    final bool neg = r < 0;
    final double a = r.abs();
    if (a >= 1e15) return v.toString();
    if (a == a.roundToDouble()) {
      final String s = a.round().toString();
      return '${neg ? '-' : ''}${group ? _groupDigits(s) : s}';
    }
    String s = a.toString();
    if (s.contains('e') || s.contains('E')) return v.toString();
    final int dot = s.indexOf('.');
    final String intPart = dot == -1 ? s : s.substring(0, dot);
    final String decPart = dot == -1 ? '' : s.substring(dot);
    return '${neg ? '-' : ''}${group ? _groupDigits(intPart) : intPart}$decPart';
  }

  static String _groupDigits(String digits) {
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }

  // ---------- الإدخال ----------

  String _currentNumber() {
    int s = _expr.length;
    while (s > 0 && _isNumChar(_expr[s - 1])) {
      s--;
    }
    return _expr.substring(s);
  }

  void _onDigit(String d) {
    if (_justEvaluated) {
      _expr = '';
      _lastLine = '';
      _justEvaluated = false;
    }
    if (_expr.length >= 100) return;
    _expr += d;
    _refresh();
  }

  void _onDot() {
    if (_justEvaluated) {
      _expr = '';
      _lastLine = '';
      _justEvaluated = false;
    }
    if (_currentNumber().contains('.')) return;
    if (_currentNumber().isEmpty) _expr += '0';
    _expr += '.';
    _refresh();
  }

  void _onOperator(String op) {
    _lastLine = '';
    _justEvaluated = false;
    if (_expr.isEmpty) {
      if (op == '−') {
        _expr = '−';
        _refresh();
      }
      return;
    }
    String last = _expr[_expr.length - 1];
    if (last == '.') {
      // إزالة الفاصلة المعلّقة: "5." ثم عملية → "5+"
      _expr = _expr.substring(0, _expr.length - 1);
      last = _expr.isEmpty ? '' : _expr[_expr.length - 1];
    }
    const List<String> ops = <String>['+', '−', '×', '÷'];
    if (_expr.isEmpty) {
      if (op == '−') {
        _expr = op;
        _refresh();
      }
      return;
    }
    if (ops.contains(last)) {
      if ((last == '×' || last == '÷') && op == '−') {
        _expr += op; // سالب أحادي بعد الضرب/القسمة
      } else {
        // إزالة كل العمليات المتتالية ثم إضافة الجديدة
        while (_expr.isNotEmpty && ops.contains(_expr[_expr.length - 1])) {
          _expr = _expr.substring(0, _expr.length - 1);
        }
        _expr += op;
      }
    } else if (last == '(' && op != '−') {
      return; // لا عملية بعد القوس مباشرة إلا السالب
    } else {
      _expr += op;
    }
    _refresh();
  }

  void _onParen() {
    if (_justEvaluated) {
      _expr = '';
      _lastLine = '';
      _justEvaluated = false;
    }
    final int open =
        '('.allMatches(_expr).length - ')'.allMatches(_expr).length;
    final bool canClose = _expr.isNotEmpty &&
        (_isNumChar(_expr[_expr.length - 1]) ||
            _expr[_expr.length - 1] == ')' ||
            _expr[_expr.length - 1] == '%');
    if (open > 0 && canClose) {
      _expr += ')';
    } else {
      if (canClose) _expr += '×'; // "5(" تتحول تلقائياً إلى "5×("
      _expr += '(';
    }
    _refresh();
  }

  void _onPercent() {
    _justEvaluated = false;
    if (_expr.isEmpty) return;
    String last = _expr[_expr.length - 1];
    if (_isNumChar(last) && _currentNumber().endsWith('.')) {
      _expr = _expr.substring(0, _expr.length - 1);
      last = _expr.isEmpty ? '' : _expr[_expr.length - 1];
    }
    if (_isNumChar(last) || last == ')' || last == '%') {
      _expr += '%';
      _refresh();
    }
  }

  void _onBackspace() {
    if (_justEvaluated) {
      _expr = '';
      _lastLine = '';
      _justEvaluated = false;
      _refresh();
      return;
    }
    if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
    _refresh();
  }

  void _onClear() {
    _expr = '';
    _lastLine = '';
    _justEvaluated = false;
    _refresh();
  }

  void _onToggleSign() {
    if (_justEvaluated) {
      _lastLine = '';
      _justEvaluated = false;
    }
    int s = _expr.length;
    while (s > 0 && _isNumChar(_expr[s - 1])) {
      s--;
    }
    if (s == _expr.length) return; // لا يوجد رقم في النهاية
    if (s > 0 &&
        _expr[s - 1] == '−' &&
        (s - 1 == 0 || _isOpOrOpen(_expr[s - 2]))) {
      _expr = '${_expr.substring(0, s - 1)}${_expr.substring(s)}'; // إزالة السالب
    } else {
      _expr = '${_expr.substring(0, s)}−${_expr.substring(s)}';
    }
    _refresh();
  }

  static bool _isOpOrOpen(String c) =>
      c == '+' || c == '−' || c == '×' || c == '÷' || c == '(';

  void _onEquals() {
    final double? v = _tryEval(_expr);
    if (v == null) {
      _refresh();
      return;
    }
    _lastLine = '$_expr =';
    _expr = _fmt(v, group: false);
    _justEvaluated = true;
    _refresh();
  }

  // ---------- الواجهة ----------

  Widget _key(
    String label,
    VoidCallback onTap, {
    IconData? icon,
    Color? bg,
    Color? fg,
    double size = 26,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bg ?? cs.surfaceContainerHighest,
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            customBorder: const StadiumBorder(),
            child: SizedBox.expand(
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 24, color: fg ?? cs.onSurface)
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: size,
                          fontWeight: FontWeight.w500,
                          color: fg ?? cs.onSurface,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // للحفاظ على الحالة عند تبديل التبويبات
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double? preview = _tryEval(_expr);
    final bool hasOp = _expr.contains(RegExp(r'[+−×÷%()]'));

    final Color altBg = cs.secondaryContainer;
    final Color altFg = cs.onSecondaryContainer;

    return Column(
      children: <Widget>[
        // شاشة العرض
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (_lastLine.isNotEmpty)
                  Text(
                    _lastLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _expr.isEmpty ? '0' : _expr,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w600,
                      color: _expr.isEmpty ? Colors.grey : cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 26,
                  child: (!_justEvaluated && preview != null && hasOp)
                      ? FittedBox(
                          child: Text(
                            '= ${_fmt(preview)}',
                            style: TextStyle(fontSize: 20, color: cs.primary),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        // لوحة الأزرار
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Row(children: <Widget>[
                    _key('C', _onClear,
                        bg: cs.errorContainer, fg: cs.onErrorContainer),
                    _key('( )', _onParen, bg: altBg, fg: altFg),
                    _key('%', _onPercent, bg: altBg, fg: altFg),
                    _key('', _onBackspace,
                        icon: Icons.backspace_outlined, bg: altBg, fg: altFg),
                  ]),
                ),
                Expanded(
                  child: Row(children: <Widget>[
                    _key('7', () => _onDigit('7')),
                    _key('8', () => _onDigit('8')),
                    _key('9', () => _onDigit('9')),
                    _key('÷', () => _onOperator('÷'), bg: altBg, fg: altFg),
                  ]),
                ),
                Expanded(
                  child: Row(children: <Widget>[
                    _key('4', () => _onDigit('4')),
                    _key('5', () => _onDigit('5')),
                    _key('6', () => _onDigit('6')),
                    _key('×', () => _onOperator('×'), bg: altBg, fg: altFg),
                  ]),
                ),
                Expanded(
                  child: Row(children: <Widget>[
                    _key('1', () => _onDigit('1')),
                    _key('2', () => _onDigit('2')),
                    _key('3', () => _onDigit('3')),
                    _key('−', () => _onOperator('−'), bg: altBg, fg: altFg),
                  ]),
                ),
                Expanded(
                  child: Row(children: <Widget>[
                    _key('+/−', _onToggleSign, size: 20),
                    _key('0', () => _onDigit('0')),
                    _key('.', _onDot),
                    _key('=', _onEquals, bg: cs.primary, fg: cs.onPrimary),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// محلّل تعبيرات رياضي (نزول تدرّجي) — بدون مكتبات خارجية
class _Parser {
  final String s;
  int i = 0;
  _Parser(this.s);

  bool get eof => i >= s.length;
  String get cur => eof ? '' : s[i];
  void _adv() => i++;

  double expression() {
    double v = term();
    while (cur == '+' || cur == '−') {
      final bool add = cur == '+';
      _adv();
      final double t = term();
      v = add ? v + t : v - t;
    }
    return v;
  }

  double term() {
    double v = unary();
    while (cur == '×' || cur == '÷') {
      final bool mul = cur == '×';
      _adv();
      final double u = unary();
      if (!mul && u == 0) throw const FormatException();
      v = mul ? v * u : v / u;
    }
    return v;
  }

  double unary() {
    if (cur == '−') {
      _adv();
      return -unary();
    }
    if (cur == '+') {
      _adv();
      return unary();
    }
    return percent();
  }

  double percent() {
    double v = atom();
    while (cur == '%') {
      _adv();
      v /= 100;
    }
    return v;
  }

  double atom() {
    if (cur == '(') {
      _adv();
      final double v = expression();
      if (cur != ')') throw const FormatException();
      _adv();
      return v;
    }
    final int start = i;
    while (!eof && _isNumChar(cur)) {
      _adv();
    }
    String t = s.substring(start, i);
    if (t.endsWith('.')) t = t.substring(0, t.length - 1);
    if (t.isEmpty) throw const FormatException();
    final double? n = double.tryParse(t);
    if (n == null) throw const FormatException();
    return n;
  }
}

// ============================================================
//  حاسبة الذهب
// ============================================================

class _GoldCalc extends StatefulWidget {
  const _GoldCalc();

  @override
  State<_GoldCalc> createState() => _GoldCalcState();
}

class _GoldCalcState extends State<_GoldCalc>
    with AutomaticKeepAliveClientMixin {
  bool _toValue = true; // true: من الوزن للقيمة، false: من المبلغ للوزن
  int _units = 0;
  final TextEditingController _price = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _price.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _pricePerGram => parseNum(_price.text);
  double get _amountVal => parseNum(_amount.text);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: <Widget>[
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.scale_outlined),
              label: Text('حساب القيمة'),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.calculate_outlined),
              label: Text('حساب الوزن'),
            ),
          ],
          selected: <bool>{_toValue},
          onSelectionChanged: (Set<bool> v) => setState(() => _toValue = v.first),
        ),
        const SizedBox(height: 16),
        if (_toValue) ...<Widget>[
          const FieldLabel('الوزن'),
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: WeightInput(
                initialUnits: _units,
                onChanged: (int u) => setState(() => _units = u),
              ),
            ),
          ),
        ] else ...<Widget>[
          const FieldLabel('المبلغ المدفوع'),
          NumberField(
            controller: _amount,
            icon: Icons.payments_outlined,
            hint: 'مثال: 100,000',
            suffix: kCurrency,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
        ],
        const FieldLabel('سعر الجرام'),
        NumberField(
          controller: _price,
          icon: Icons.sell_outlined,
          hint: 'مثال: 8,500',
          suffix: '$kCurrency / جرام',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _result(),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'كل جرام = 10 حبات = 100 جزء',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _result() {
    final double price = _pricePerGram;
    if (price <= 0) return _hintBox('أدخل سعر الجرام أولاً');

    if (_toValue) {
      if (_units <= 0) return _hintBox('أدخل الوزن');
      final double grams = unitsToGrams(_units);
      final double value = grams * price;
      return _goldBox(
        <Widget>[
          _kv('الوزن', '${unitsToWeight(_units)} جرام'),
          _kv('سعر الجرام', fmtMoney(price)),
          _kv('سعر الحبة', fmtMoney(price / kUnitsPerGram * kUnitsPerHabba)),
          _kv('سعر الجزء', fmtMoney(price / kUnitsPerGram)),
          const Divider(height: 22),
          FittedBox(
            child: Text(
              fmtMoney(value),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: kDarkGold),
            ),
          ),
          const Text('القيمة الإجمالية',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      );
    }

    // حساب الوزن من المبلغ
    if (_amountVal <= 0) return _hintBox('أدخل المبلغ المدفوع');
    final int units = (_amountVal / price * kUnitsPerGram).floor();
    if (units <= 0) return _hintBox('المبلغ أقل من سعر جزء واحد');
    final double grams = unitsToGrams(units);
    final double residual = _amountVal - grams * price;
    return _goldBox(
      <Widget>[
        _kv('المبلغ', fmtMoney(_amountVal)),
        _kv('سعر الجرام', fmtMoney(price)),
        const Divider(height: 22),
        FittedBox(
          child: Text(
            '${unitsToWeight(units)} جرام',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: kDarkGold),
          ),
        ),
        const Text('الوزن المستحق',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 8),
        Text(
          'بالأعشار: ${grams.toStringAsFixed(2)} جرام',
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
        if (residual > 0.004)
          Text(
            'المتبقي من المبلغ: ${fmtMoney(residual)}',
            style: const TextStyle(
                fontSize: 12.5, color: kGreen, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _goldBox(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kGoldLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGold, width: 1.6),
        ),
        child: Column(children: children),
      );

  Widget _hintBox(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13.5),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(k,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Text(v,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13.5)),
          ],
        ),
      );
}
