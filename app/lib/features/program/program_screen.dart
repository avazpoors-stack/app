import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

/// تب برنامه — در فاز P1 برنامه‌های JSON (آغاز، خانه‌ساز، رشد، شروع کوتاه) اینجا می‌آیند.
class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('برنامه')),
      body: const EmptyState(
        icon: Icons.event_note,
        title: 'برنامه‌های تمرینی',
        message: 'در فاز P1، چهار برنامهٔ لنگر (آغاز، خانه‌ساز، رشد، شروع کوتاه) به این صفحه اضافه می‌شود.',
      ),
    );
  }
}
