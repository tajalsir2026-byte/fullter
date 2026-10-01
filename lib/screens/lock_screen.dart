import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../data/cloud_sync.dart';
import '../data/security.dart';
import 'home_shell.dart';

/// ============================================================
///  بوابة الحماية
///  - تقفل التطبيق تلقائياً بعد الخروج منه (مدة قابلة للضبط)
///  - تحمي من التخمين بتأخير تصاعدي بعد 5 محاولات
/// ============================================================
class AppLock extends StatefulWidget {
  const AppLock({super.key});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _loading = true;
  bool _unlocked = false;
  bool _hasPassword = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    _hasPassword = await Security.instance.hasPassword();
    await AppStore.instance.load();
    await CloudSync.instance.init();
    if (mounted) setState(() => _loading = false);
    // مزامنة صامتة عند بدء التشغيل (تفشل بهدوء لو مافي نت)
    if (CloudSync.instance.signedIn) {
      CloudSync.instance.sync(silent: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final DateTime? p = _pausedAt;
      _pausedAt = null;
      if (CloudSync.instance.signedIn) {
        CloudSync.instance.sync(silent: true);
      }
      if (p == null || !_unlocked) return;
      Security.instance.lockSeconds().then((int limit) {
        if (DateTime.now().difference(p).inSeconds >= limit && mounted) {
          setState(() => _unlocked = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kGold)),
      );
    }
    if (_unlocked) return const HomeShell();
    return PasswordScreen(
      isSetup: !_hasPassword,
      onSuccess: () => setState(() {
        _hasPassword = true;
        _unlocked = true;
      }),
    );
  }
}

class PasswordScreen extends StatefulWidget {
  final bool isSetup;
  final VoidCallback onSuccess;
  const PasswordScreen({
    super.key,
    required this.isSetup,
    required this.onSuccess,
  });

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController p1 = TextEditingController();
  final TextEditingController p2 = TextEditingController();
  String? err;
  bool busy = false;
  Timer? _timer;
  int _blocked = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final int b = Security.instance.blockedSeconds;
      if (b != _blocked && mounted) setState(() => _blocked = b);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    p1.dispose();
    p2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy) return;
    final String v = normalizeDigits(p1.text);
    if (v.length != 4) {
      setState(() => err = 'يجب أن يكون 4 أرقام');
      return;
    }
    setState(() => busy = true);

    if (widget.isSetup) {
      if (normalizeDigits(p2.text) != v) {
        setState(() {
          err = 'الرقم غير مطابق';
          busy = false;
        });
        return;
      }
      await Security.instance.setPassword(v);
      widget.onSuccess();
      return;
    }

    final bool ok = await Security.instance.verify(v);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      final int b = Security.instance.blockedSeconds;
      setState(() {
        err = b > 0
            ? 'محاولات كثيرة خاطئة — انتظر $b ثانية'
            : 'الرقم السري خطأ';
        busy = false;
        _blocked = b;
        p1.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool blocked = _blocked > 0;
    return Scaffold(
      backgroundColor: kGoldLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: kGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.isSetup ? 'إنشاء كلمة السر' : kAppName,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kDarkGold),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isSetup
                      ? 'اختر 4 أرقام لحماية بياناتك'
                      : 'أدخل كلمة السر للدخول',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                _pinField(p1, widget.isSetup ? 'الرقم السري' : '••••',
                    autofocus: true, enabled: !blocked, onDone: () {
                  if (!widget.isSetup && normalizeDigits(p1.text).length == 4) {
                    _submit();
                  }
                }),
                if (widget.isSetup) ...<Widget>[
                  const SizedBox(height: 12),
                  _pinField(p2, 'تأكيد الرقم'),
                ],
                if (err != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(err!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: kRed, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: blocked || busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      blocked
                          ? 'انتظر $_blocked ثانية'
                          : (widget.isSetup ? 'حفظ' : 'دخول'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                if (widget.isSetup) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    'انتبه: لا يمكن استرجاع كلمة السر إذا نسيتها.\n'
                    'احتفظ بنسخة احتياطية من بياناتك دائماً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinField(
    TextEditingController c,
    String hint, {
    bool autofocus = false,
    bool enabled = true,
    VoidCallback? onDone,
  }) {
    return TextField(
      controller: c,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 28, letterSpacing: 12),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (String v) {
        if (err != null) setState(() => err = null);
        if (normalizeDigits(v).length == 4 && onDone != null) onDone();
      },
    );
  }
}
