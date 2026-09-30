import 'package:flutter/material.dart';

import '../core/constants.dart';

/// عمود في الجدول
class GoldCol {
  final String title;
  final double width;
  const GoldCol(this.title, this.width);
}

/// خلية في الجدول
class GoldCell {
  final String text;
  final Color? color;
  final FontWeight weight;
  const GoldCell(this.text, {this.color, this.weight = FontWeight.normal});
}

/// ============================================================
///  جدول موحّد لكل الشاشات:
///  - تمرير أفقي واحد يشمل الرأس والصفوف وصف الإجمالي
///  - تمرير رأسي محسّن (ListView.builder) يتحمّل آلاف الصفوف
/// ============================================================
class GoldTable extends StatelessWidget {
  final List<GoldCol> columns;
  final int rowCount;
  final List<GoldCell> Function(int index) rowBuilder;
  final List<GoldCell>? footer;
  final void Function(int index)? onRowTap;
  final Color Function(int index)? rowColor;

  const GoldTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    this.footer,
    this.onRowTap,
    this.rowColor,
  });

  double get _totalWidth =>
      columns.fold<double>(0, (double s, GoldCol c) => s + c.width);

  Widget _cell(GoldCell c, double width, Color? bg, double fontSize) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      color: bg,
      alignment: Alignment.center,
      child: Text(
        c.text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c.color ?? Colors.black87,
          fontWeight: c.weight,
          fontSize: fontSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // الرأس
              Container(
                color: kGold,
                child: Row(
                  children: columns
                      .map((GoldCol c) => _cell(
                            GoldCell(c.title,
                                color: Colors.white, weight: FontWeight.bold),
                            c.width,
                            null,
                            12.5,
                          ))
                      .toList(),
                ),
              ),
              // الصفوف
              Expanded(
                child: ListView.builder(
                  itemCount: rowCount,
                  itemBuilder: (BuildContext ctx, int i) {
                    final List<GoldCell> cells = rowBuilder(i);
                    final Color bg = rowColor?.call(i) ??
                        (dark
                            ? (i.isEven
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFF212121))
                            : (i.isEven ? Colors.white : kGoldLight));
                    return InkWell(
                      onTap: onRowTap == null ? null : () => onRowTap!(i),
                      child: Row(
                        children: <Widget>[
                          for (int c = 0;
                              c < columns.length && c < cells.length;
                              c++)
                            _cell(
                              dark && cells[c].color == null
                                  ? GoldCell(cells[c].text,
                                      color: Colors.white70,
                                      weight: cells[c].weight)
                                  : cells[c],
                              columns[c].width,
                              bg,
                              12,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // الإجمالي
              if (footer != null)
                Container(
                  color: kDarkGold,
                  child: Row(
                    children: <Widget>[
                      for (int c = 0;
                          c < columns.length && c < footer!.length;
                          c++)
                        _cell(footer![c], columns[c].width, null, 12.5),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// رسالة "لا توجد بيانات"
class EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyHint({super.key, required this.text, this.icon = Icons.inbox});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
