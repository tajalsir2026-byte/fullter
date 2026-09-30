import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';

/// ============================================================
///  النسخ الاحتياطي على شكل ملفات JSON داخل مجلد التطبيق
///  المسار على أندرويد:
///  /storage/emulated/0/Android/data/<package>/files/backups/
///  (يمكن الوصول إليه من أي مدير ملفات، ونسخه إلى الواتساب أو الذاكرة)
/// ============================================================
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  Future<Directory> folder() async {
    Directory? base;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        base = await getExternalStorageDirectory();
      }
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// يحفظ نسخة جديدة ويرجع الملف
  Future<File> save(String json) async {
    final Directory dir = await folder();
    final DateTime now = DateTime.now();
    final String stamp =
        '${dateSortStr(now)}_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final File file = File('${dir.path}/gold_backup_$stamp.json');
    await file.writeAsString(json);
    return file;
  }

  /// كل النسخ المحفوظة، الأحدث أولاً
  Future<List<File>> list() async {
    final Directory dir = await folder();
    final List<File> files = <File>[];
    await for (final FileSystemEntity e in dir.list()) {
      if (e is File && e.path.endsWith('.json')) files.add(e);
    }
    files.sort((File a, File b) => b.path.compareTo(a.path));
    return files;
  }

  Future<String> read(File f) => f.readAsString();

  Future<void> delete(File f) async {
    if (await f.exists()) await f.delete();
  }

  String fileLabel(File f) {
    final String name = f.uri.pathSegments.last;
    final String core = name.replaceAll('gold_backup_', '').replaceAll('.json', '');
    final List<String> parts = core.split('_');
    if (parts.length == 2 && parts[1].length == 6) {
      final String t = parts[1];
      return '${parts[0]}  —  ${t.substring(0, 2)}:${t.substring(2, 4)}';
    }
    return name;
  }

  String sizeLabel(File f) {
    try {
      final int b = f.lengthSync();
      if (b < 1024) return '$b بايت';
      return '${(b / 1024).toStringAsFixed(1)} ك.ب';
    } catch (_) {
      return '';
    }
  }
}
