import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/cloud_sync.dart';
import 'form_fields.dart';

/// بطاقة المزامنة السحابية في شاشة الإعدادات
class CloudSyncCard extends StatefulWidget {
  const CloudSyncCard({super.key});

  @override
  State<CloudSyncCard> createState() => _CloudSyncCardState();
}

class _CloudSyncCardState extends State<CloudSyncCard> {
  final TextEditingController mail = TextEditingController();
  final TextEditingController pass = TextEditingController();
  final CloudSync cloud = CloudSync.instance;
  bool showPass = false;

  @override
  void initState() {
    super.initState();
    mail.text = cloud.email ?? '';
  }

  @override
  void dispose() {
    mail.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final String? msg = await action();
    if (!mounted || msg == null) return;
    final bool bad = msg.contains('فشل') ||
        msg.contains('تعذّر') ||
        msg.contains('غير صحيح') ||
        msg.contains('خطأ') ||
        msg.contains('سجّل') ||
        msg.contains('قصيرة') ||
        msg.contains('مسجَّل');
    showMsg(context, msg, error: bad);
    if (!bad) pass.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cloud,
      builder: (BuildContext context, Widget? _) {
        if (!cloud.configured) {
          return _box(
            color: Colors.grey.shade100,
            border: Colors.grey.shade400,
            child: const Text(
              'المزامنة غير مفعّلة في هذه النسخة.\n'
              'تُفعَّل بإضافة رابط ومفتاح Supabase في ملف cloud_config.dart.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          );
        }

        if (!cloud.signedIn) return _signInForm();
        return _signedInBox();
      },
    );
  }

  Widget _box({
    required Widget child,
    Color? color,
    Color? border,
  }) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color ?? kGoldLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? kGold.withValues(alpha: 0.5)),
        ),
        child: child,
      );

  Widget _signInForm() {
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.cloud_off, color: kDarkGold, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سجّل بنفس الإيميل وكلمة السر في كل الأجهزة لتتوحّد البيانات',
                  style: TextStyle(fontSize: 12.5, color: kDarkGold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: mail,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            decoration: fieldDecoration(Icons.email, hint: 'الإيميل'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pass,
            obscureText: !showPass,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock),
              hintText: 'كلمة السر (6 أحرف فأكثر)',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              suffixIcon: IconButton(
                icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => showPass = !showPass),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (cloud.busy)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: kGold),
            ))
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kGold),
                    onPressed: () =>
                        _run(() => cloud.signIn(mail.text, pass.text)),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('تسجيل دخول'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _run(() => cloud.signUp(mail.text, pass.text)),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('إنشاء حساب'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const Text(
            'أول جهاز: «إنشاء حساب». باقي الأجهزة: «تسجيل دخول» بنفس البيانات.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _signedInBox() {
    return _box(
      color: kGreen.withValues(alpha: 0.07),
      border: kGreen.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cloud_done, color: kGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('المزامنة مفعّلة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: kGreen)),
                    Text(
                      cloud.email ?? '',
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.black54),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            cloud.busy
                ? 'جاري المزامنة...'
                : cloud.lastSync == null
                    ? 'لم تتم أي مزامنة بعد'
                    : 'آخر مزامنة: ${dateLongStr(cloud.lastSync!)} '
                        '${cloud.lastSync!.hour.toString().padLeft(2, '0')}:'
                        '${cloud.lastSync!.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 12.5),
          ),
          if (cloud.lastError != null) ...<Widget>[
            const SizedBox(height: 6),
            Text('آخر خطأ: ${cloud.lastError}',
                style: const TextStyle(fontSize: 11.5, color: kRed)),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kGreen),
                  onPressed:
                      cloud.busy ? null : () => _run(() => cloud.sync()),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('مزامنة الآن'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: cloud.busy
                    ? null
                    : () async {
                        final bool ok = await confirmDialog(
                          context,
                          title: 'تسجيل الخروج',
                          message:
                              'بياناتك على هذا الجهاز لن تُحذف، لكن ستتوقف المزامنة.',
                          okLabel: 'خروج',
                          okColor: kRed,
                        );
                        if (ok) await cloud.signOut();
                      },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('خروج'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'المزامنة تتم تلقائياً عند فتح التطبيق وبعد كل تعديل (عند توفر النت).',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
