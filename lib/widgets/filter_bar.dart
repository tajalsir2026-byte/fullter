import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';

enum Period { all, today, week, month, custom }

/// حالة الفلترة (فترة زمنية + بحث نصي)
class TableFilter {
  Period period;
  DateTimeRange? custom;
  String query;

  TableFilter({this.period = Period.all, this.custom, this.query = ''});

  bool get isActive => period != Period.all || query.trim().isNotEmpty;

  bool matchDate(DateTime d) {
    final DateTime now = DateTime.now();
    switch (period) {
      case Period.all:
        return true;
      case Period.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case Period.week:
        final DateTime from = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        return !d.isBefore(from);
      case Period.month:
        return d.year == now.year && d.month == now.month;
      case Period.custom:
        if (custom == null) return true;
        final DateTime s = DateTime(
            custom!.start.year, custom!.start.month, custom!.start.day);
        final DateTime e = DateTime(
            custom!.end.year, custom!.end.month, custom!.end.day, 23, 59, 59);
        return !d.isBefore(s) && !d.isAfter(e);
    }
  }

  bool matchText(List<String> fields) {
    final String q = normalizeDigits(query.trim()).toLowerCase();
    if (q.isEmpty) return true;
    for (final String f in fields) {
      if (normalizeDigits(f).toLowerCase().contains(q)) return true;
    }
    return false;
  }

  String get label {
    switch (period) {
      case Period.all:
        return 'الكل';
      case Period.today:
        return 'اليوم';
      case Period.week:
        return 'آخر 7 أيام';
      case Period.month:
        return 'هذا الشهر';
      case Period.custom:
        return custom == null
            ? 'فترة'
            : '${dateStr(custom!.start)} - ${dateStr(custom!.end)}';
    }
  }
}

/// شريط البحث والفلترة أعلى الجداول
class FilterBar extends StatelessWidget {
  final TableFilter filter;
  final VoidCallback onChanged;
  final String searchHint;

  const FilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.searchHint = 'بحث...',
  });

  Future<void> _pickCustom(BuildContext context) async {
    final DateTimeRange? r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: filter.custom,
      locale: const Locale('ar'),
    );
    if (r != null) {
      filter.custom = r;
      filter.period = Period.custom;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 42,
              child: TextField(
                onChanged: (String v) {
                  filter.query = v;
                  onChanged();
                },
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  _chip(context, 'الكل', Period.all),
                  _chip(context, 'اليوم', Period.today),
                  _chip(context, 'آخر 7 أيام', Period.week),
                  _chip(context, 'هذا الشهر', Period.month),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        filter.period == Period.custom
                            ? filter.label
                            : 'فترة مخصّصة',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: filter.period == Period.custom
                          ? kGold.withValues(alpha: 0.2)
                          : null,
                      onPressed: () => _pickCustom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Period p) {
    final bool sel = filter.period == p;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: sel,
        selectedColor: kGold.withValues(alpha: 0.25),
        onSelected: (_) {
          filter.period = p;
          onChanged();
        },
      ),
    );
  }
}
