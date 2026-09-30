import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// ============================================================
///  الحماية: كلمة السر تُخزَّن كبصمة (SHA-256 + ملح عشوائي)
///  ولا تُخزَّن أبداً كنص صريح.
/// ============================================================
class Security {
  Security._();
  static final Security instance = Security._();

  int _failedAttempts = 0;
  DateTime? _blockedUntil;

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  String _newSalt() {
    final Random r = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<bool> hasPassword() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(StoreKeys.passwordHash) != null ||
        prefs.getString(StoreKeys.legacyPassword) != null;
  }

  Future<void> setPassword(String password) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String salt = _newSalt();
    await prefs.setString(StoreKeys.passwordSalt, salt);
    await prefs.setString(StoreKeys.passwordHash, _hash(password, salt));
    await prefs.remove(StoreKeys.legacyPassword); // إزالة النص الصريح القديم
    _failedAttempts = 0;
    _blockedUntil = null;
  }

  /// كم ثانية متبقية على الحظر بعد المحاولات الخاطئة (0 = غير محظور)
  int get blockedSeconds {
    if (_blockedUntil == null) return 0;
    final int s = _blockedUntil!.difference(DateTime.now()).inSeconds;
    return s > 0 ? s : 0;
  }

  Future<bool> verify(String password) async {
    if (blockedSeconds > 0) return false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // ترحيل: لو كانت محفوظة بالنص الصريح من النسخة القديمة
    final String? legacy = prefs.getString(StoreKeys.legacyPassword);
    if (legacy != null) {
      if (legacy == password) {
        await setPassword(password); // نحوّلها لبصمة مشفّرة
        return true;
      }
      _registerFailure();
      return false;
    }

    final String? salt = prefs.getString(StoreKeys.passwordSalt);
    final String? hash = prefs.getString(StoreKeys.passwordHash);
    if (salt == null || hash == null) return false;

    final bool ok = _hash(password, salt) == hash;
    if (ok) {
      _failedAttempts = 0;
      _blockedUntil = null;
    } else {
      _registerFailure();
    }
    return ok;
  }

  void _registerFailure() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      // تأخير تصاعدي: 30ث، 60ث، 120ث ... بحد أقصى 5 دقائق
      final int extra = _failedAttempts - 4;
      final int seconds = (30 * extra).clamp(30, 300);
      _blockedUntil = DateTime.now().add(Duration(seconds: seconds));
    }
  }

  int get failedAttempts => _failedAttempts;

  /// مدة القفل التلقائي عند الخروج من التطبيق (بالثواني، 0 = فوراً)
  Future<int> lockSeconds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StoreKeys.lockSeconds) ?? 60;
  }

  Future<void> setLockSeconds(int s) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StoreKeys.lockSeconds, s);
  }
}
