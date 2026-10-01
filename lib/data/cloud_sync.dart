import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/cloud_config.dart';
import '../core/constants.dart';
import 'app_store.dart';
import 'sync_merge.dart';

/// ============================================================
///  المزامنة السحابية عبر Supabase
///
///  - اتصال مباشر بواجهة HTTP (بدون حزم ثقيلة)
///  - التطبيق يعمل أوفلاين بالكامل؛ المزامنة إضافة فوقه
///  - عند المزامنة: نسحب نسخة السحابة، ندمجها مع المحلية، ثم نرفع الناتج
/// ============================================================
class CloudSync extends ChangeNotifier {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  String? email;
  String? _userId;
  String? _accessToken;
  String? _refreshToken;
  DateTime? lastSync;

  bool busy = false;
  String? lastError;
  String statusText = '';

  Timer? _debounce;

  bool get configured => kCloudConfigured;
  bool get signedIn => _accessToken != null && _userId != null;

  Map<String, String> get _headers => <String, String>{
        'apikey': kSupabaseAnonKey,
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // ---------------------------------------------------------
  // الجلسة
  // ---------------------------------------------------------
  Future<void> init() async {
    if (!configured) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    email = p.getString(StoreKeys.cloudEmail);
    _userId = p.getString(StoreKeys.cloudUserId);
    _accessToken = p.getString(StoreKeys.cloudAccessToken);
    _refreshToken = p.getString(StoreKeys.cloudRefreshToken);
    final String? ls = p.getString(StoreKeys.cloudLastSync);
    lastSync = ls == null ? null : DateTime.tryParse(ls);

    // أي تغيير محلي يجدول مزامنة
    AppStore.instance.syncHook = scheduleSync;
    notifyListeners();
  }

  Future<void> _saveSession() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    if (email == null) {
      await p.remove(StoreKeys.cloudEmail);
      await p.remove(StoreKeys.cloudUserId);
      await p.remove(StoreKeys.cloudAccessToken);
      await p.remove(StoreKeys.cloudRefreshToken);
      await p.remove(StoreKeys.cloudLastSync);
    } else {
      await p.setString(StoreKeys.cloudEmail, email!);
      if (_userId != null) await p.setString(StoreKeys.cloudUserId, _userId!);
      if (_accessToken != null) {
        await p.setString(StoreKeys.cloudAccessToken, _accessToken!);
      }
      if (_refreshToken != null) {
        await p.setString(StoreKeys.cloudRefreshToken, _refreshToken!);
      }
      if (lastSync != null) {
        await p.setString(StoreKeys.cloudLastSync, lastSync!.toIso8601String());
      }
    }
  }

  void _readSession(Map<String, dynamic> j) {
    _accessToken = j['access_token']?.toString();
    _refreshToken = j['refresh_token']?.toString();
    final dynamic user = j['user'];
    if (user is Map) _userId = user['id']?.toString();
  }

  /// رسالة خطأ بالعربية من رد Supabase
  String _errorMessage(http.Response r) {
    try {
      final dynamic j = jsonDecode(r.body);
      final String raw = (j is Map
              ? (j['msg'] ?? j['message'] ?? j['error_description'] ?? j['error'])
              : null)
              ?.toString() ??
          r.body;
      final String low = raw.toLowerCase();
      if (low.contains('invalid login')) return 'الإيميل أو كلمة السر غير صحيحة';
      if (low.contains('already registered') ||
          low.contains('already been registered')) {
        return 'هذا الإيميل مسجَّل من قبل — استخدم «تسجيل دخول»';
      }
      if (low.contains('password should be')) {
        return 'كلمة السر قصيرة — 6 أحرف على الأقل';
      }
      if (low.contains('unable to validate email') ||
          low.contains('invalid email')) {
        return 'صيغة الإيميل غير صحيحة';
      }
      if (low.contains('email not confirmed')) {
        return 'الحساب يحتاج تأكيد الإيميل — عطّل Confirm email من لوحة Supabase';
      }
      return raw;
    } catch (_) {
      return 'خطأ (${r.statusCode})';
    }
  }

  Future<String?> signUp(String mail, String password) async {
    if (!configured) return 'المزامنة غير مفعّلة في هذه النسخة';
    busy = true;
    notifyListeners();
    try {
      final http.Response r = await http
          .post(
            Uri.parse('$kSupabaseUrl/auth/v1/signup'),
            headers: <String, String>{
              'apikey': kSupabaseAnonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
                <String, String>{'email': mail.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      if (r.statusCode >= 400) return _errorMessage(r);

      final Map<String, dynamic> j =
          Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      _readSession(j);
      if (_accessToken == null) {
        // تأكيد الإيميل مفعّل في لوحة Supabase
        return 'تم إنشاء الحساب، لكن يلزم تأكيد الإيميل. '
            'عطّل Confirm email من لوحة Supabase ثم سجّل دخول.';
      }
      email = mail.trim();
      await _saveSession();
      notifyListeners();
      return await sync();
    } catch (e) {
      return 'تعذّر الاتصال: ${_netMsg(e)}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> signIn(String mail, String password) async {
    if (!configured) return 'المزامنة غير مفعّلة في هذه النسخة';
    busy = true;
    notifyListeners();
    try {
      final http.Response r = await http
          .post(
            Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
            headers: <String, String>{
              'apikey': kSupabaseAnonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
                <String, String>{'email': mail.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      if (r.statusCode >= 400) return _errorMessage(r);

      _readSession(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
      email = mail.trim();
      await _saveSession();
      notifyListeners();
      return await sync();
    } catch (e) {
      return 'تعذّر الاتصال: ${_netMsg(e)}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    email = null;
    _userId = null;
    _accessToken = null;
    _refreshToken = null;
    lastSync = null;
    await _saveSession();
    notifyListeners();
  }

  /// تجديد التوكن عند انتهاء صلاحيته
  Future<bool> _refresh() async {
    if (_refreshToken == null) return false;
    try {
      final http.Response r = await http
          .post(
            Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
            headers: <String, String>{
              'apikey': kSupabaseAnonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{'refresh_token': _refreshToken!}),
          )
          .timeout(const Duration(seconds: 30));
      if (r.statusCode >= 400) return false;
      _readSession(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
      await _saveSession();
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }

  String _netMsg(Object e) {
    final String s = e.toString().toLowerCase();
    if (s.contains('timeout')) return 'الشبكة بطيئة، حاول مرة أخرى';
    if (s.contains('failed host lookup') || s.contains('socketexception')) {
      return 'لا يوجد اتصال بالإنترنت';
    }
    return e.toString();
  }

  // ---------------------------------------------------------
  // المزامنة
  // ---------------------------------------------------------

  /// مزامنة مؤجلة بعد كل تعديل محلي (حتى لا نرفع مع كل ضغطة)
  void scheduleSync() {
    if (!signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () => sync(silent: true));
  }

  /// سحب + دمج + رفع. يرجع رسالة للمستخدم (أو null عند النجاح الصامت)
  Future<String?> sync({bool silent = false}) async {
    if (!configured) return 'المزامنة غير مفعّلة';
    if (!signedIn) return 'سجّل الدخول أولاً';
    if (busy && silent) return null;

    busy = true;
    statusText = 'جاري المزامنة...';
    notifyListeners();

    try {
      // 1) سحب نسخة السحابة
      http.Response r = await _get();
      if (r.statusCode == 401) {
        if (!await _refresh()) {
          return 'انتهت الجلسة — سجّل الدخول مرة أخرى';
        }
        r = await _get();
      }
      if (r.statusCode >= 400) return _errorMessage(r);

      Map<String, dynamic> remote = <String, dynamic>{};
      final List<dynamic> rows = jsonDecode(r.body) as List<dynamic>;
      if (rows.isNotEmpty) {
        final Map<String, dynamic> row =
            Map<String, dynamic>.from(rows.first as Map);
        if (row['payload'] is Map) {
          remote = Map<String, dynamic>.from(row['payload'] as Map);
        }
      }

      // 2) الدمج
      final Map<String, dynamic> local = AppStore.instance.exportPayload();
      final Map<String, dynamic> merged = mergePayloads(local, remote);

      // 3) حفظ الناتج محلياً
      await AppStore.instance.applyPayload(merged, notify: true);

      // 4) رفع الناتج
      final http.Response up = await http
          .post(
            Uri.parse('$kSupabaseUrl/rest/v1/app_data'),
            headers: <String, String>{
              ..._headers,
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': _userId,
                'payload': merged,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }
            ]),
          )
          .timeout(const Duration(seconds: 40));

      if (up.statusCode >= 400) return _errorMessage(up);

      lastSync = DateTime.now();
      lastError = null;
      await _saveSession();

      final int n = (merged['purchases'] as List<dynamic>).length +
          (merged['sales'] as List<dynamic>).length +
          (merged['expenses'] as List<dynamic>).length +
          (merged['partners'] as List<dynamic>).length;
      statusText = 'تمت المزامنة ($n سجل)';
      return silent ? null : statusText;
    } catch (e) {
      lastError = _netMsg(e);
      statusText = 'فشلت المزامنة: $lastError';
      return silent ? null : statusText;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<http.Response> _get() => http
      .get(
        Uri.parse(
            '$kSupabaseUrl/rest/v1/app_data?select=payload&user_id=eq.$_userId'),
        headers: _headers,
      )
      .timeout(const Duration(seconds: 40));
}
