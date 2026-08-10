import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/jalali.dart';
import '../../core/theme/app_colors.dart';

/// صفحهٔ پایان تمرین: انفجار امتیاز + استریک + رنک + پیام شخصیتی + کارت اشتراک.
class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.result,
    required this.message,
    required this.programName,
    required this.sessionName,
  });

  final WorkoutResult result;
  final String message;
  final String programName;
  final String sessionName;

  static const Map<String, String> _breakdownLabels = {
    'sets': 'ست‌های ثبت‌شده',
    'exercises': 'حرکت‌های کامل',
    'workout': 'تکمیل تمرین',
    'first': 'اولین تمرین',
    'streak': 'جایزهٔ استریک',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, size: 64, color: AppColors.gold),
                const SizedBox(height: 12),
                Text('تمرین کامل شد!', style: textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '$programName — $sessionName',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  '+${JalaliDate.faDigits(result.earned.toString())} امتیاز',
                  style: textTheme.displaySmall?.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final entry in result.breakdown.entries)
                          if (entry.value > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_breakdownLabels[entry.key] ?? entry.key),
                                  Text(
                                    '+${JalaliDate.faDigits(entry.value.toString())}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('مجموع امتیازها',
                                style: textTheme.titleSmall),
                            Text(
                              '${JalaliDate.faDigits(result.totalPoints.toString())}',
                              style: textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('استریک', style: textTheme.titleSmall),
                            Text(
                              '🔥 ${JalaliDate.faDigits(result.streak.toString())} روز',
                              style: textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('رنک', style: textTheme.titleSmall),
                            Text(
                              '${result.rank.emoji} ${result.rank.name}',
                              style: textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '«$message»',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.orange,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _ShareCardPreview(result: result),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: const Text('بازگشت به خانه'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// پیش‌نمایش کارت اشتراک‌گذاری — لوگوی حامی در فازهای بعد اضافه می‌شود.
class _ShareCardPreview extends StatelessWidget {
  const _ShareCardPreview({required this.result});

  final WorkoutResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF121212)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'بدنه',
            style: TextStyle(
              color: AppColors.orange,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'ساختاری که می‌سازی.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('استریک', '${JalaliDate.faDigits(result.streak.toString())} روز'),
              _stat('امتیاز', '${JalaliDate.faDigits(result.totalPoints.toString())}'),
              _stat('رنک', result.rank.name),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '🔒 اشتراک‌گذاری واقعی در فاز P2 (این فقط پیش‌نمایش است)',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

