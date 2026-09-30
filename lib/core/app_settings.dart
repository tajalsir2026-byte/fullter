import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// إعدادات المظهر (فاتح / داكن / حسب النظام)
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String v = prefs.getString(StoreKeys.themeMode) ?? 'light';
    themeMode.value = switch (v) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode.value = m;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StoreKeys.themeMode,
      switch (m) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      },
    );
  }
}
