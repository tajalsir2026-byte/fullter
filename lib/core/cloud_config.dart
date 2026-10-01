/// ============================================================
/// إعدادات المزامنة السحابية عبر Supabase
///
/// هذا المفتاح Publishable ومصمم للاستخدام داخل تطبيق الهاتف.
/// الحماية الحقيقية تعتمد على سياسات RLS في قاعدة البيانات.
///
/// لا تضع أبداً مفتاح Secret أو service_role هنا.
/// ============================================================

library;

const String kSupabaseUrl =
    'https://htmjdarvlfdyndfgkcqr.supabase.co';

const String kSupabaseAnonKey =
    'sb_publishable_G6q93VDW6wNeUQQfBAYMJA_fA76A5Fs';

bool get kCloudConfigured =>
    kSupabaseUrl.trim().isNotEmpty &&
    kSupabaseAnonKey.trim().isNotEmpty;
