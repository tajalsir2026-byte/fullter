import 'package:flutter/material.dart';

const kGold = Color(0xFFB8860B);
const kDarkGold = Color(0xFF4A3800);
const kGeneral = 'عام';

String fmtNum(double n) {
  final s = n.abs().toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

String weightToString(double w) {
  final g = w.floor();
  final rem = w - g;
  final h = (rem * 10).floor();
  final j = ((rem * 100) - (h * 10)).round();
  return '$g.$h.$j';
}

String dateStr(DateTime d) => '${d.day}/${d.month}/${d.year}';
