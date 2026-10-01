/// ============================================================
///  منطق دمج البيانات بين الأجهزة
///
///  القواعد:
///  1) السجلات تُدمج بالمعرّف (id) — اتحاد الطرفين
///  2) لو نفس السجل موجود في الطرفين، يفوز **الأحدث** (updatedAt)
///  3) الحذف يُسجَّل كـ «علامة حذف» (tombstone) بتاريخه، فينتقل للجهاز الآخر
///  4) علامة الحذف تُلغي السجل فقط إذا كانت أحدث من آخر تعديل له
///     (يعني لو عدّلته في جهاز بعد ما حذفته في جهاز آخر، التعديل يفوز)
///
///  كل الدوال هنا خالصة (بدون شبكة) ليسهل اختبارها.
/// ============================================================
library;

const List<String> kSyncLists = <String>[
  'purchases',
  'sales',
  'expenses',
  'partners',
];

DateTime _ts(dynamic v) {
  if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(v.toString())?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

List<Map<String, dynamic>> _asRows(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  return v
      .whereType<Map<dynamic, dynamic>>()
      .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
      .where((Map<String, dynamic> e) => e['id'] != null)
      .toList();
}

Map<String, String> _asTombstones(dynamic v) {
  final Map<String, String> out = <String, String>{};
  if (v is Map) {
    v.forEach((dynamic k, dynamic val) {
      if (k != null && val != null) out[k.toString()] = val.toString();
    });
  }
  return out;
}

/// يدمج حمولتين (محلية وبعيدة) وينتج الحمولة الموحّدة
Map<String, dynamic> mergePayloads(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  // 1) دمج علامات الحذف (الأحدث يفوز)
  final Map<String, String> deleted =
      Map<String, String>.from(_asTombstones(local['deleted']));
  _asTombstones(remote['deleted']).forEach((String id, String ts) {
    final String? cur = deleted[id];
    if (cur == null || _ts(ts).isAfter(_ts(cur))) deleted[id] = ts;
  });

  final Map<String, dynamic> out = <String, dynamic>{};

  for (final String key in kSyncLists) {
    final Map<String, Map<String, dynamic>> byId =
        <String, Map<String, dynamic>>{};

    void absorb(List<Map<String, dynamic>> rows) {
      for (final Map<String, dynamic> r in rows) {
        final String id = r['id'].toString();
        final Map<String, dynamic>? cur = byId[id];
        if (cur == null || _ts(r['updatedAt']).isAfter(_ts(cur['updatedAt']))) {
          byId[id] = r;
        }
      }
    }

    absorb(_asRows(local[key]));
    absorb(_asRows(remote[key]));

    // 2) تطبيق علامات الحذف
    final List<Map<String, dynamic>> kept = <Map<String, dynamic>>[];
    for (final MapEntry<String, Map<String, dynamic>> e in byId.entries) {
      final String? delTs = deleted[e.key];
      if (delTs != null && !_ts(e.value['updatedAt']).isAfter(_ts(delTs))) {
        continue; // محذوف ولم يُعدَّل بعد الحذف
      }
      // لو عُدّل بعد الحذف، نلغي علامة الحذف
      if (delTs != null) deleted.remove(e.key);
      kept.add(e.value);
    }

    out[key] = kept;
  }

  out['deleted'] = deleted;
  return out;
}

/// ينظّف علامات الحذف القديمة جداً (بعد 90 يوماً لم تعد مفيدة)
Map<String, String> pruneTombstones(Map<String, String> deleted,
    {DateTime? now, int days = 90}) {
  final DateTime cut =
      (now ?? DateTime.now()).toUtc().subtract(Duration(days: days));
  final Map<String, String> out = <String, String>{};
  deleted.forEach((String id, String ts) {
    if (_ts(ts).isAfter(cut)) out[id] = ts;
  });
  return out;
}
