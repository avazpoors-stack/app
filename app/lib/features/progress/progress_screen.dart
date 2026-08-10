import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/services/jalali.dart';
import '../../core/services/streak.dart';
import '../../core/theme/app_colors.dart';
import '../search/global_search_button.dart';

/// تب پیشرفت — آمار کل؛ نمودار ۷ روز در فازهای بعد.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<UserProgress> _future;

  @override
  void initState() {
    super.initState();
    _future = BadaneScope.of(context).ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پیشرفت'),
        actions: const [GlobalSearchButton()],
      ),
      body: FutureBuilder<UserProgress>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('خطا در بارگذاری'));
          }
          final progress = snapshot.data!;
          final services = BadaneScope.of(context);
          var rank = services.content.ranks.first;
          for (final r in services.content.ranks) {
            if (progress.totalPoints >= r.minPoints) rank = r;
          }
          final streak = computeStreak(
              progress.workouts.map(_dateOf).toList(),
              services.clock.now());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text('${rank.emoji} ${rank.name}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        'امتیاز کل: ${JalaliDate.faDigits(progress.totalPoints.toString())}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat(context, 'جلسه‌ها',
                              '${JalaliDate.faDigits(progress.workouts.length.toString())}'),
                          _stat(context, 'استریک',
                              '${JalaliDate.faDigits(streak.toString())} روز'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'نمودار فعالیت ۷ روز اخیر در فاز P3 اضافه می‌شود.',
                style: TextStyle(color: AppColors.textMutedLight, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppColors.orange, fontWeight: FontWeight.bold)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMutedLight)),
      ],
    );
  }
}

DateTime _dateOf(WorkoutEntry w) {
  final parts = w.date.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
