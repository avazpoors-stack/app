import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

/// تب پیشرفت — در فاز P1 امتیاز/استریک/رنک و در فازهای بعد نمودارها اینجا می‌آیند.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پیشرفت')),
      body: const EmptyState(
        icon: Icons.insights,
        title: 'آمار پیشرفت',
        message: 'در فاز P1، امتیاز، استریک و رنک و در فازهای بعد نمودار فعالیت به این صفحه اضافه می‌شود.',
      ),
    );
  }
}
