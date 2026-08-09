import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

/// تب پروفایل — تنظیمات (تم دارک/لایت، تقویم شمسی، لحن مربی) در فاز P2 می‌آیند.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل')),
      body: const EmptyState(
        icon: Icons.person,
        title: 'پروفایل و تنظیمات',
        message: 'در فاز P2، ثبت‌نام/ورود، تم دارک/لایت و تنظیمات به این صفحه اضافه می‌شود.',
      ),
    );
  }
}
