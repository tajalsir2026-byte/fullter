/// ============================================================
///  إعدادات المزامنة السحابية (Supabase)
///
///  ضع هنا قيمتين من لوحة تحكم Supabase:
///  Project Settings ← API
///
///  - kSupabaseUrl      = Project URL   مثال: https://abcd1234.supabase.co
///  - kSupabaseAnonKey  = anon public   (النص الطويل الذي يبدأ بـ eyJ...)
///
///  ملاحظة أمنية: مفتاح anon مصمَّم ليكون داخل التطبيق ومكشوفاً،
///  والحماية الحقيقية هي قواعد RLS في قاعدة البيانات (كل مستخدم يرى بياناته فقط).
///  لا تضع أبداً مفتاح service_role هنا.
///
///  إذا تُركت القيمتان فارغتين، يعمل التطبيق بشكل طبيعي بدون مزامنة.
/// ============================================================
library;

const String kSupabaseUrl = '';
const String kSupabaseAnonKey = '';

bool get kCloudConfigured =>
    kSupabaseUrl.trim().isNotEmpty && kSupabaseAnonKey.trim().isNotEmpty;
