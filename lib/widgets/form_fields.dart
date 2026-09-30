import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/format.dart';

/// عنوان فوق الحقل
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(
        children: <Widget>[
          Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (required)
            const Text(' *', style: TextStyle(color: kRed, fontSize: 15)),
        ],
      ),
    );
  }
}

InputDecoration fieldDecoration(IconData icon, {String? hint, String? suffix}) =>
    InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hint,
      suffixText: suffix,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );

/// حقل رقمي (يقبل الأرقام العربية أيضاً)
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final String? suffix;
  final bool decimal;
  final ValueChanged<String>? onChanged;

  const NumberField({
    super.key,
    required this.controller,
    this.icon = Icons.numbers,
    this.hint,
    this.suffix,
    this.decimal = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textAlign: TextAlign.center,
      onChanged: onChanged,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,\-]')),
      ],
      decoration: fieldDecoration(icon, hint: hint, suffix: suffix),
    );
  }
}

/// ============================================================
///  إدخال الوزن (جرام . حبة . جزء)
///  يمنع إدخال حبة/جزء أكبر من 9 تلقائياً بالترحيل
///  (مثال: 15 حبة تصبح 1 جرام و5 حبات)
/// ============================================================
class WeightInput extends StatefulWidget {
  final int initialUnits;
  final ValueChanged<int> onChanged;
  const WeightInput({
    super.key,
    required this.initialUnits,
    required this.onChanged,
  });

  @override
  State<WeightInput> createState() => _WeightInputState();
}

class _WeightInputState extends State<WeightInput> {
  late final TextEditingController g;
  late final TextEditingController h;
  late final TextEditingController j;

  @override
  void initState() {
    super.initState();
    final int u = widget.initialUnits;
    g = TextEditingController(text: u == 0 ? '' : (u ~/ kUnitsPerGram).toString());
    h = TextEditingController(
        text: u == 0 ? '' : ((u % kUnitsPerGram) ~/ kUnitsPerHabba).toString());
    j = TextEditingController(text: u == 0 ? '' : (u % kUnitsPerHabba).toString());
  }

  @override
  void dispose() {
    g.dispose();
    h.dispose();
    j.dispose();
    super.dispose();
  }

  int get units =>
      parseInt(g.text) * kUnitsPerGram +
      parseInt(h.text) * kUnitsPerHabba +
      parseInt(j.text);

  void _emit() {
    widget.onChanged(units);
    setState(() {});
  }

  /// يعيد توزيع القيم (الترحيل) عند الخروج من الحقول
  void _normalize() {
    final int u = units;
    g.text = (u ~/ kUnitsPerGram).toString();
    h.text = ((u % kUnitsPerGram) ~/ kUnitsPerHabba).toString();
    j.text = (u % kUnitsPerHabba).toString();
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _box(g, 'جرام')),
            const SizedBox(width: 6),
            Expanded(child: _box(h, 'حبة')),
            const SizedBox(width: 6),
            Expanded(child: _box(j, 'جزء')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text('الوزن: ${unitsToWeight(units)}',
                style: const TextStyle(
                    color: kGold, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            TextButton.icon(
              onPressed: _normalize,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('ترتيب', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _box(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onChanged: (_) => _emit(),
      onEditingComplete: _normalize,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

/// اختيار العيار مع أزرار سريعة
class PurityField extends StatefulWidget {
  final TextEditingController controller;
  const PurityField({super.key, required this.controller});

  @override
  State<PurityField> createState() => _PurityFieldState();
}

class _PurityFieldState extends State<PurityField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NumberField(
          controller: widget.controller,
          icon: Icons.diamond,
          hint: 'مثال: 21',
          decimal: false,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: kCommonPurities
              .map((int p) => ChoiceChip(
                    label: Text('$p'),
                    selected: parseInt(widget.controller.text) == p,
                    selectedColor: kGold.withValues(alpha: 0.25),
                    onSelected: (_) {
                      widget.controller.text = '$p';
                      setState(() {});
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// زر حفظ عريض
class SaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const SaveButton({super.key, required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.save),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

/// حقل اختيار التاريخ
class DateField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const DateField({super.key, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime? p = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          locale: const Locale('ar'),
        );
        if (p != null) onChanged(p);
      },
      child: InputDecorator(
        decoration: fieldDecoration(Icons.calendar_today),
        child: Text(dateLongStr(date)),
      ),
    );
  }
}

void showMsg(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? kRed : kGreen,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'حذف',
  Color okColor = kRed,
}) async {
  final bool? r = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel,
              style: TextStyle(color: okColor, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return r == true;
}
