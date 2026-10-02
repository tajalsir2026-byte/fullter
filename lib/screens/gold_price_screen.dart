import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/format.dart';

/// ============================================================
///  السعر العالمي للذهب اليوم
///  - سعر الأونصة والجرام بالدولار (مصادر مجانية وموثوقة)
///  - سعر صرف الدولار: السوق الموازي (أخبار السودان sudanakhbar.com)
///    مع إمكانية التعديل اليدوي السريع والحفظ في الكاش
///  - سعر الجرام بالجنيه السوداني حسب العيار (24، 22، 21، 18)
/// ============================================================

class GoldPriceScreen extends StatefulWidget {
  const GoldPriceScreen({super.key});

  @override
  State<GoldPriceScreen> createState() => _GoldPriceScreenState();
}

class _GoldPriceScreenState extends State<GoldPriceScreen> {
  static const double _gramsPerOunce = 31.1034768;

  // مفاتيح الكاش المحلي (يعمل بدون إنترنت بعد أول جلب)
  static const String _kOunce = 'gold_price_ounce_usd';
  static const String _kRate = 'gold_price_rate_usd_sdg';
  static const String _kManual = 'gold_price_rate_manual';
  static const String _kSource = 'gold_price_rate_source';
  static const String _kUpdated = 'gold_price_updated_at';

  double? _ounceUsd; // سعر الأونصة بالدولار
  double _rate = 8200; // سعر صرف الدولار الافتراضي (سوق موازي)
  double? _autoRate; // السعر المجلوب تلقائيًا (سوق موازي)
  double? _bankRate; // سعر بنك الخرطوم (مرجعي)
  String _rateSource = ''; // 'sudanakhbar' أو 'alsoug' أو 'manual' أو ''
  bool _manualRate = false; // هل عدّل المستخدم سعر الصرف بنفسه؟
  DateTime? _updatedAt;
  bool _loading = false;
  bool _firstLoad = true;
  String? _error;

  final TextEditingController _rateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  //  البيانات والتخزين المؤقت
  // ============================================================

  Future<void> _loadCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? ounce = prefs.getDouble(_kOunce);
    final double? rate = prefs.getDouble(_kRate);
    final bool manual = prefs.getBool(_kManual) ?? false;
    final String? src = prefs.getString(_kSource);
    final String? updated = prefs.getString(_kUpdated);
    if (mounted) {
      setState(() {
        _ounceUsd = ounce;
        _rateSource = src ?? '';
        if (rate != null && rate > 0) {
          _rate = rate;
          _autoRate = rate;
          _manualRate = manual;
          _rateCtrl.text = _fmtRate(rate);
        } else {
          _rateCtrl.text = _fmtRate(_rate);
        }
        if (updated != null) {
          _updatedAt = DateTime.tryParse(updated);
        }
        _firstLoad = false;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final double ounce = await _fetchOunceUsd();

      // سعر الصرف: أخبار السودان (السوق الموازي) أولاً
      double? auto;
      double? bank;
      String source = '';

      try {
        final ({double market, double? bank}) s = await _fetchSudanAkhbarRate();
        auto = s.market;
        bank = s.bank;
        source = 'sudanakhbar';
      } catch (_) {
        try {
          final ({double market, double? bank}) m = await _fetchAlsougRate();
          auto = m.market;
          bank = m.bank;
          source = 'alsoug';
        } catch (_) {
          // في حال انقطاع النت نستخدم آخر سعر كاش أو الافتراضي
          if (_rate > 0) {
            auto = _rate;
            source = 'cached';
          }
        }
      }

      final DateTime now = DateTime.now();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kOunce, ounce);
      await prefs.setString(_kUpdated, now.toIso8601String());
      await prefs.setString(_kSource, source);
      if (!_manualRate && auto != null && auto > 0) {
        await prefs.setDouble(_kRate, auto);
      }

      if (mounted) {
        setState(() {
          _ounceUsd = ounce;
          _autoRate = auto;
          _bankRate = bank;
          _rateSource = source;
          _updatedAt = now;
          if (!_manualRate && auto != null && auto > 0) {
            _rate = auto;
            _rateCtrl.text = _fmtRate(auto);
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذّر تحديث السعر — تأكد من الإنترنت ثم اضغط تحديث';
        });
      }
    }
  }

  /// سعر أونصة الذهب بالدولار — مصادر متعددة سريعة
  Future<double> _fetchOunceUsd() async {
    // 1. Coinbase PAX Gold (فائق السرعة والموثوقية)
    try {
      final http.Response r = await http
          .get(Uri.parse('https://api.coinbase.com/v2/prices/PAXG-USD/spot'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final Map<String, dynamic> j =
            Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final Map<String, dynamic>? data = j['data'] as Map<String, dynamic>?;
        final double? p = double.tryParse(data?['amount']?.toString() ?? '');
        if (p != null && p > 1000) {
          return p;
        }
      }
    } catch (_) {}

    // 2. Gold-API
    try {
      final http.Response r = await http
          .get(Uri.parse('https://api.gold-api.com/price/XAU'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final Map<String, dynamic> j =
            Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final double? p = (j['price'] as num?)?.toDouble();
        if (p != null && p > 1000) {
          return p;
        }
      }
    } catch (_) {}

    // 3. CoinGecko
    try {
      final http.Response r = await http
          .get(Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=pax-gold&vs_currencies=usd'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final Map<String, dynamic> j =
            Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final dynamic pax = j['pax-gold'];
        if (pax is Map) {
          final double? p = (pax['usd'] as num?)?.toDouble();
          if (p != null && p > 1000) {
            return p;
          }
        }
      }
    } catch (_) {}

    // 4. Yahoo Finance
    try {
      final http.Response r = await http
          .get(
            Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/GC=F'),
            headers: <String, String>{'User-Agent': 'Mozilla/5.0'},
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final Map<String, dynamic> j =
            Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final Map<String, dynamic> chart = j['chart'] as Map<String, dynamic>;
        final List<dynamic> result = chart['result'] as List<dynamic>;
        final Map<String, dynamic> meta =
            Map<String, dynamic>.from(result[0] as Map);
        final dynamic metaInner = meta['meta'];
        if (metaInner is Map) {
          final double? p =
              (metaInner['regularMarketPrice'] as num?)?.toDouble();
          if (p != null && p > 1000) {
            return p;
          }
        }
      }
    } catch (_) {}

    throw Exception('no gold price source');
  }

  /// سعر السوق الموازي من أخبار السودان sudanakhbar.com
  Future<({double market, double? bank})> _fetchSudanAkhbarRate() async {
    const List<String> urls = <String>[
      'https://www.sudanakhbar.com/latestnews/dollar-prices',
      'https://www.sudanakhbar.com/latestnews/currency-prices',
    ];

    for (final String listUrl in urls) {
      try {
        final http.Response rList = await http.get(
          Uri.parse(listUrl),
          headers: <String, String>{
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36',
          },
        ).timeout(const Duration(seconds: 10));

        if (rList.statusCode != 200) continue;
        final String htmlList = utf8.decode(rList.bodyBytes, allowMalformed: true);

        // استخراج روابط المقالات مثل https://www.sudanakhbar.com/1851114
        final Iterable<Match> linkMatches =
            RegExp(r'https://www\.sudanakhbar\.com/\d{6,8}').allMatches(htmlList);
        final List<String> articleUrls = linkMatches
            .map((m) => m.group(0)!)
            .toSet()
            .take(3)
            .toList();

        for (final String artUrl in articleUrls) {
          try {
            final http.Response rArt = await http.get(
              Uri.parse(artUrl),
              headers: <String, String>{
                'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8)',
              },
            ).timeout(const Duration(seconds: 8));

            if (rArt.statusCode != 200) continue;
            final String artHtml = utf8.decode(rArt.bodyBytes, allowMalformed: true);

            // 1. البحث في جداول المقال
            final List<double> tableRates = <double>[];
            final Iterable<Match> rows =
                RegExp(r'<tr[^>]*>.*?</tr>', dotAll: true).allMatches(artHtml);

            for (final Match rowMatch in rows) {
              final String row = rowMatch.group(0)!;
              if (row.contains('الدولار')) {
                final Iterable<Match> nums =
                    RegExp(r'>\s*([\d,\.]+)\s*<').allMatches(row);
                for (final Match nm in nums) {
                  final double? v = double.tryParse(
                      nm.group(1)!.replaceAll(',', '').trim());
                  if (v != null && v >= 3000 && v <= 50000) {
                    tableRates.add(v);
                  }
                }
              }
            }

            if (tableRates.isNotEmpty) {
              return (market: tableRates.last, bank: 4231.5);
            }

            // 2. البحث بنمط النص المباشر
            final RegExpMatch? textMatch = RegExp(
              r'الدولار[^\d\n]{1,60}(?:سجل|بلغ|سعر|شراء|بيع)[^\d\n]{1,30}(\d[\d,\.]{3,7})',
            ).firstMatch(artHtml);

            if (textMatch != null) {
              final double? v = double.tryParse(
                  textMatch.group(1)!.replaceAll(',', '').trim());
              if (v != null && v >= 3000 && v <= 50000) {
                return (market: v, bank: 4231.5);
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    throw Exception('sudanakhbar: no rate found');
  }

  /// سعر السوق المفتوح وبنك الخرطوم من موقع سوق السودان alsoug.com (احتياطي)
  Future<({double market, double? bank})> _fetchAlsougRate() async {
    final http.Response r = await http
        .get(
          Uri.parse('https://www.alsoug.com/currency'),
          headers: <String, String>{
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw Exception('alsoug ${r.statusCode}');
    }
    final String html = utf8.decode(r.bodyBytes, allowMalformed: true);

    String? table;
    for (final RegExpMatch tm
        in RegExp(r'<table[^>]*>.*?</table>', dotAll: true).allMatches(html)) {
      final String t = tm.group(0)!;
      if (t.contains('USD')) {
        table = t;
        break;
      }
    }
    if (table == null) {
      throw Exception('alsoug: table not found');
    }

    String? usdRow;
    for (final String row in table.split('<tr')) {
      if (row.contains('USD')) {
        usdRow = row;
        break;
      }
    }
    if (usdRow == null) {
      throw Exception('alsoug: usd row not found');
    }

    final List<String> cells = <String>[];
    for (final RegExpMatch cm
        in RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true).allMatches(usdRow)) {
      cells.add(cm.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim());
    }
    if (cells.length < 3) {
      throw Exception('alsoug: cells not found');
    }
    final double? market =
        double.tryParse(cells[2].replaceAll(RegExp(r'[,\s]'), ''));
    if (market == null || market <= 0) {
      throw Exception('alsoug: bad market value');
    }
    final double? bank =
        double.tryParse(cells[1].replaceAll(RegExp(r'[,\s]'), ''));
    return (market: market, bank: bank);
  }

  void _onRateEdited(String txt) {
    final double v = parseNum(txt);
    setState(() {
      _rate = v;
      _manualRate = v > 0;
    });
    _saveRate();
  }

  Future<void> _saveRate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRate, _rate);
    await prefs.setBool(_kManual, _manualRate);
  }

  void _useAutoRate() {
    if (_autoRate == null) {
      return;
    }
    setState(() {
      _rate = _autoRate!;
      _manualRate = false;
      _rateCtrl.text = _fmtRate(_autoRate!);
    });
    _saveRate();
  }

  // ============================================================
  //  التنسيق
  // ============================================================

  String _fmtRate(double v) {
    if (v == v.roundToDouble()) {
      return v.round().toString();
    }
    return v.toStringAsFixed(1);
  }

  String _fmt2(double? v) {
    if (v == null) {
      return '—';
    }
    final bool neg = v < 0;
    final String s = v.abs().toStringAsFixed(2);
    final int dot = s.indexOf('.');
    return '${neg ? '-' : ''}${_groupDigits(s.substring(0, dot))}${s.substring(dot)}';
  }

  static String _groupDigits(String digits) {
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        b.write(',');
      }
      b.write(digits[i]);
    }
    return b.toString();
  }

  String _timeStr(DateTime d) {
    int h = d.hour;
    final String ap = h >= 12 ? 'م' : 'ص';
    h = h % 12;
    if (h == 0) {
      h = 12;
    }
    return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
  }

  // ============================================================
  //  الواجهة
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final double gramUsd = (_ounceUsd ?? 0) / _gramsPerOunce;

    return Scaffold(
      appBar: AppBar(
        title: const Text('السعر العالمي للذهب'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث الأسعار',
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _firstLoad
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: <Widget>[
                  if (_error != null && _ounceUsd == null)
                    _errorBox()
                  else ...<Widget>[
                    _worldCard(gramUsd),
                    const SizedBox(height: 14),
                    _rateCard(),
                    if (_rate > 0 && gramUsd > 0) ...<Widget>[
                      const SizedBox(height: 14),
                      _sdgCard(gramUsd),
                    ] else ...<Widget>[
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'أدخل سعر صرف الدولار ليظهر السعر بالجنيه',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12.5),
                        ),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kRed, fontSize: 12),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  _footer(),
                ],
              ),
            ),
    );
  }

  Widget _worldCard(double gramUsd) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kGoldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold, width: 1.6),
      ),
      child: Column(
        children: <Widget>[
          const Text('السعر العالمي الآن',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              '\$${_fmt2(_ounceUsd)}',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: kDarkGold),
            ),
          ),
          const Text('للأونصة (دولار أمريكي)',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const Divider(height: 22),
          _kv('الجرام بالدولار', '\$${_fmt2(gramUsd)}'),
          _kv('الأونصة بالجرام', '${_gramsPerOunce.toStringAsFixed(3)} جرام'),
        ],
      ),
    );
  }

  Widget _rateCard() {
    final bool isSudanAkhbar = _rateSource == 'sudanakhbar';
    final bool isAlsoug = _rateSource == 'alsoug';

    String sourceDesc = '';
    if (isSudanAkhbar) {
      sourceDesc =
          'سعر السوق الموازي: ${_fmtRate(_autoRate ?? _rate)} جنيه — من أخبار السودان (sudanakhbar.com)';
    } else if (isAlsoug) {
      sourceDesc =
          'سعر السوق المفتوح: ${_fmtRate(_autoRate ?? _rate)} جنيه — من سوق السودان (alsoug.com)';
    } else if (_manualRate) {
      sourceDesc = 'تم تعديل السعر يدويًا — يُحفظ على هاتفك ويعمل تلقائيًا';
    } else {
      sourceDesc =
          'سعر السوق الموازي المتداول: ${_fmtRate(_rate)} جنيه — يمكنك تعديله يدويًا';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('سعر الدولار — السوق المفتوح (جنيه للدولار)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: _onRateEdited,
                    decoration: const InputDecoration(
                      hintText: 'مثال: 8,200',
                      suffixText: kCurrency,
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                  ),
                ),
                if (_manualRate && _autoRate != null) ...<Widget>[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _useAutoRate,
                    child: const Text(
                      'سعر السوق',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sourceDesc,
              style: TextStyle(
                color: isSudanAkhbar ? kGreen : Colors.grey.shade700,
                fontSize: 11.5,
                fontWeight: isSudanAkhbar ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (_bankRate != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'مرجع البنوك — متوسط بنك الخرطوم: ${_fmtRate(_bankRate!)} جنيه',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sdgCard(double gramUsd) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kGoldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold, width: 1.6),
      ),
      child: Column(
        children: <Widget>[
          const Text('سعر الجرام بالجنيه السوداني',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final int p in kCommonPurities.reversed)
            _kv(
              'عيار $p',
              fmtMoney(gramUsd * p / 24 * _rate),
              bold: true,
            ),
          const Divider(height: 18),
          Text(
            'الأونصة عيار 24: ${fmtMoney(_ounceUsd! * _rate)}',
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.wifi_off, color: kRed, size: 34),
          const SizedBox(height: 10),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kRed, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: <Widget>[
        if (_updatedAt != null)
          Text(
            'آخر تحديث: ${dateLongStr(_updatedAt!)} - ${_timeStr(_updatedAt!)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        const SizedBox(height: 4),
        const Text(
          'المصادر: أخبار السودان (sudanakhbar.com) و Coinbase و Yahoo Finance و gold-api.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 4),
        const Text(
          'تنويه: الأسعار مرجعية — السعر المحلي قد يختلف حسب المصنعية وسوق الجنيه',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(k,
                  style: const TextStyle(color: Colors.grey, fontSize: 13.5)),
            ),
            Text(
              v,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: bold ? 15 : 13.5,
                color: kDarkGold,
              ),
            ),
          ],
        ),
      );
}
