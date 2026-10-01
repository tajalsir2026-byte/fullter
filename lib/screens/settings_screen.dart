import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_settings.dart';
import '../core/constants.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../data/backup.dart';
import '../data/security.dart';
import '../widgets/cloud_card.dart';
import '../widgets/form_fields.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppStore store = AppStore.instance;
  int lockSeconds = 60;
  String? folderPath;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    lockSeconds = await Security.instance.lockSeconds();
    try {
      final Directory d = await BackupService.instance.folder();
      folderPath = d.path;
    } catch (_) {
      folderPath = null;
    }
    if (mounted) setState(() {});
  }

  // ---------------- كلمة السر ----------------
  Future<void> _changePassword() async {
    final TextEditingController oldC = TextEditingController();
    final TextEditingController p1 = TextEditingController();
    final TextEditingController p2 = TextEditingController();
    String? err;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setS) =>
            AlertDialog(
          title: const Text('تغيير كلمة السر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _pin(oldC, 'كلمة السر الحالية'),
                const SizedBox(height: 10),
                _pin(p1, 'الرقم الجديد'),
                const SizedBox(height: 10),
                _pin(p2, 'تأكيد الرقم الجديد'),
                if (err != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(err!, style: const TextStyle(color: kRed)),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
              onPressed: () async {
                final String o = normalizeDigits(oldC.text);
                final String a = normalizeDigits(p1.text);
                final String b = normalizeDigits(p2.text);
                if (!await Security.instance.verify(o)) {
                  setS(() => err = 'كلمة السر الحالية خطأ');
                  return;
                }
                if (a.length != 4) {
                  setS(() => err = 'يجب أن يكون 4 أرقام');
                  return;
                }
                if (a != b) {
                  setS(() => err = 'الرقم غير مطابق');
                  return;
                }
                await Security.instance.setPassword(a);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('حفظ',
                  style:
                      TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) showMsg(context, 'تم تغيير كلمة السر');
  }

  Widget _pin(TextEditingController c, String hint) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, letterSpacing: 8),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
        ],
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
      );

  Future<void> _pickLockTime() async {
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('القفل التلقائي بعد الخروج'),
        children: <Widget>[
          for (final (int s, String label) in <(int, String)>[
            (0, 'فوراً'),
            (30, 'بعد 30 ثانية'),
            (60, 'بعد دقيقة'),
            (300, 'بعد 5 دقائق'),
            (1800, 'بعد 30 دقيقة'),
          ])
            ListTile(
              leading: Icon(
                lockSeconds == s
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: kGold,
              ),
              title: Text(label),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (v != null) {
      await Security.instance.setLockSeconds(v);
      setState(() => lockSeconds = v);
    }
  }

  String get lockLabel => switch (lockSeconds) {
        0 => 'فوراً',
        30 => 'بعد 30 ثانية',
        60 => 'بعد دقيقة',
        300 => 'بعد 5 دقائق',
        1800 => 'بعد 30 دقيقة',
        _ => 'بعد $lockSeconds ثانية',
      };

  // ---------------- النسخ الاحتياطي ----------------
  Future<void> _createBackup() async {
    try {
      final File f = await BackupService.instance.save(store.exportJson());
      if (!mounted) return;
      showMsg(context, 'تم حفظ النسخة: ${f.uri.pathSegments.last}');
      setState(() {});
    } catch (e) {
      if (mounted) showMsg(context, 'فشل إنشاء النسخة: $e', error: true);
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (mounted) {
      showMsg(context, 'تم نسخ البيانات — الصقها في الواتساب أو الملاحظات');
    }
  }

  Future<void> _restoreFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String text = data?.text ?? '';
    if (text.trim().isEmpty) {
      if (mounted) showMsg(context, 'الحافظة فارغة', error: true);
      return;
    }
    if (!mounted) return;
    final bool ok = await confirmDialog(
      context,
      title: 'استعادة من الحافظة',
      message: 'سيتم استبدال كل البيانات الحالية بالبيانات الملصوقة. متأكد؟',
      okLabel: 'استعادة',
      okColor: kGold,
    );
    if (!ok) return;
    final String msg = await store.importJson(text);
    if (mounted) showMsg(context, msg);
  }

  Future<void> _openBackupsList() async {
    final List<File> files = await BackupService.instance.list();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setS) =>
            SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('النسخ المحفوظة',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (files.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('لا توجد نسخ محفوظة بعد',
                            style: TextStyle(color: Colors.grey))),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView(
                      shrinkWrap: true,
                      children: files
                          .map((File f) => ListTile(
                                leading:
                                    const Icon(Icons.description, color: kGold),
                                title: Text(
                                    BackupService.instance.fileLabel(f)),
                                subtitle:
                                    Text(BackupService.instance.sizeLabel(f)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'استعادة',
                                      icon: const Icon(Icons.restore,
                                          color: kGreen),
                                      onPressed: () async {
                                        final bool ok = await confirmDialog(
                                          ctx,
                                          title: 'استعادة النسخة',
                                          message:
                                              'سيتم استبدال البيانات الحالية بنسخة '
                                              '${BackupService.instance.fileLabel(f)}',
                                          okLabel: 'استعادة',
                                          okColor: kGold,
                                        );
                                        if (!ok) return;
                                        final String raw =
                                            await BackupService.instance
                                                .read(f);
                                        final String msg =
                                            await store.importJson(raw);
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (mounted) showMsg(context, msg);
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      icon: const Icon(Icons.delete,
                                          color: kRed),
                                      onPressed: () async {
                                        await BackupService.instance
                                            .delete(f);
                                        files.remove(f);
                                        setS(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                if (folderPath != null)
                  Text(
                    'مسار المجلد:\n$folderPath',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _wipe() async {
    final bool ok = await confirmDialog(
      context,
      title: 'حذف كل البيانات',
      message: 'سيتم حذف كل المشتريات والمبيعات والمنصرفات والشركاء.\n'
          'لا يمكن التراجع! تأكد أن عندك نسخة احتياطية.',
      okLabel: 'حذف الكل',
    );
    if (!ok) return;
    if (!mounted) return;
    final bool ok2 = await confirmDialog(
      context,
      title: 'تأكيد أخير',
      message: 'متأكد 100%؟',
      okLabel: 'نعم، احذف',
    );
    if (!ok2) return;
    await store.wipeAll();
    if (mounted) showMsg(context, 'تم حذف كل البيانات');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: ListenableBuilder(
        listenable: store,
        builder: (BuildContext context, Widget? _) => ListView(
          children: <Widget>[
            _section('الحماية'),
            ListTile(
              leading: const Icon(Icons.lock, color: kGold),
              title: const Text('تغيير كلمة السر'),
              subtitle: const Text('الرقم السري المكوّن من 4 أرقام'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
              onTap: _changePassword,
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: kGold),
              title: const Text('القفل التلقائي'),
              subtitle: Text(lockLabel),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
              onTap: _pickLockTime,
            ),

            _section('المظهر'),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: AppSettings.instance.themeMode,
              builder: (BuildContext c, ThemeMode mode, Widget? _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('فاتح'),
                        icon: Icon(Icons.light_mode)),
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('داكن'),
                        icon: Icon(Icons.dark_mode)),
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('النظام'),
                        icon: Icon(Icons.phone_android)),
                  ],
                  selected: <ThemeMode>{mode},
                  onSelectionChanged: (Set<ThemeMode> v) =>
                      AppSettings.instance.setThemeMode(v.first),
                ),
              ),
            ),

            _section('المزامنة بين الأجهزة'),
            const CloudSyncCard(),

            _section('النسخ الاحتياطي'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kGoldLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGold.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.info_outline, color: kDarkGold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'بياناتك محفوظة داخل الجهاز فقط. خُذ نسخة احتياطية بانتظام '
                      'حتى لا تفقدها عند تغيير الهاتف.\n'
                      'عندك ${store.purchases.length} مشترى، '
                      '${store.sales.length} بيع، '
                      '${store.expenses.length} مصروف، '
                      '${store.partners.length} شريك.',
                      style: const TextStyle(
                          fontSize: 12.5, color: kDarkGold, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.save, color: kGreen),
              title: const Text('إنشاء نسخة احتياطية الآن'),
              subtitle: const Text('تُحفظ كملف JSON داخل مجلد التطبيق'),
              onTap: _createBackup,
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: kGold),
              title: const Text('النسخ المحفوظة والاستعادة'),
              subtitle: const Text('عرض النسخ السابقة واستعادتها'),
              onTap: _openBackupsList,
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: kBlue),
              title: const Text('نسخ البيانات كنص'),
              subtitle: const Text('لإرسالها عبر الواتساب أو الإيميل'),
              onTap: _copyToClipboard,
            ),
            ListTile(
              leading: const Icon(Icons.paste, color: kBlue),
              title: const Text('استعادة من نص منسوخ'),
              subtitle: const Text('لصق نسخة احتياطية من الحافظة'),
              onTap: _restoreFromClipboard,
            ),

            _section('البيانات'),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: kRed),
              title: const Text('حذف كل البيانات',
                  style: TextStyle(color: kRed)),
              subtitle: const Text('لا يمكن التراجع'),
              onTap: _wipe,
            ),

            _section('عن التطبيق'),
            const ListTile(
              leading: Icon(Icons.info, color: kGold),
              title: Text(kAppName),
              subtitle: Text('النسخة $kAppVersion'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: <Widget>[
            Container(width: 4, height: 16, color: kGold),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      );
}
