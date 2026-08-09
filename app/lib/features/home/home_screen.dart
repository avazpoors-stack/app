import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

/// تب خانه — در فاز P1 چرخهٔ طلایی (انرژی → تمرین امروز → ثبت ست) اینجا ساخته می‌شود.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بدنه')),
      body: const EmptyState(
        icon: Icons.fitness_center,
        title: 'تمرین امروز',
        message: 'در فاز P1، چرخهٔ طلایی تمرین (انتخاب انرژی، تمرین امروز و ثبت ست) به این صفحه اضافه می‌شود.',
      ),
    );
  }
}
