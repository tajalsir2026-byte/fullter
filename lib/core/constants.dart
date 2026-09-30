import 'package:flutter/material.dart';

/// ===== ثوابت التطبيق =====
/// لتغيير اسم التطبيق الظاهر غيّر kAppName هنا
/// و android/app/src/main/AndroidManifest.xml (android:label)
const String kAppName = 'حسابات الذهب';
const String kAppVersion = '4.0.0';
const String kCurrency = 'ج.س';

/// اسم "المصروف العام" (غير مخصوم من شريك معيّن)
const String kGeneral = 'عام';

/// كل جرام = 10 حبات = 100 جزء
const int kUnitsPerGram = 100;
const int kUnitsPerHabba = 10;

// ===== الألوان =====
const Color kGold = Color(0xFFB8860B);
const Color kGoldLight = Color(0xFFFFF8E1);
const Color kDarkGold = Color(0xFF4A3800);
const Color kGreen = Color(0xFF2E7D32);
const Color kRed = Color(0xFFC62828);
const Color kBlue = Color(0xFF1565C0);

/// مفاتيح التخزين في SharedPreferences
class StoreKeys {
  static const String purchases = 'purchases_v2';
  static const String sales = 'sales_v1';
  static const String expenses = 'expenses_v1';
  static const String partners = 'partners_v1';

  static const String passwordHash = 'app_password_hash';
  static const String passwordSalt = 'app_password_salt';
  static const String legacyPassword = 'app_password'; // النسخة القديمة (نص صريح)

  static const String lockSeconds = 'lock_after_seconds';
  static const String themeMode = 'theme_mode';
  static const String lastBackup = 'last_backup_at';
}

/// فئات المصروفات الجاهزة (يمكن للمستخدم كتابة فئة جديدة)
const List<String> kDefaultCategories = [
  'كهرباء',
  'مياه',
  'إيجار',
  'فطور',
  'مواصلات',
  'اتصالات',
  'صيانة',
  'رواتب',
  'ضرائب',
  'أخرى',
];

/// العيارات الشائعة
const List<int> kCommonPurities = [18, 21, 22, 24];
