import 'package:flutter/material.dart';

/// هویت برند «بدنه» — پالت نارنجی-خاکستری الهام‌گرفته از سلیقهٔ حامی
/// (تم بام بانک ملی) + رنگ‌های موفقیت مسترپلن.
/// منبع: docs/DESIGN_REFERENCE.md و docs/BADANE_MASTERPLAN.md
abstract final class AppColors {
  // رنگ‌های برند (در هر دو تم ثابت)
  static const Color orange = Color(0xFFFF6B35); // اکشن اصلی
  static const Color orangePressed = Color(0xFFE85A2A);
  static const Color gold = Color(0xFFFFB800); // پاداش/مدال
  static const Color successGreen = Color(0xFF4CD964); // موفقیت

  // تم روشن (لایت)
  static const Color bgLight = Color(0xFFF4F4F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF212121);
  static const Color textMutedLight = Color(0xFF6B7280);

  // تم تیره (دارک)
  static const Color bgDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textDark = Color(0xFFECECEC);
  static const Color textMutedDark = Color(0xFF9CA3AF);
}
