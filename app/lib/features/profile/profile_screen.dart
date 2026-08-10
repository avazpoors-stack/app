import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/app_colors.dart';

/// تب پروفایل — انتخاب لحن مربی (فاز P1)؛ بقیهٔ تنظیمات در P2.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProgress> _future;

  @override
  void initState() {
    super.initState();
    _future = BadaneScope.of(context).ensureLoaded();
  }

  Future<void> _setTone(CoachTone tone) async {
    final services = BadaneScope.of(context);
    await services.progress.setTone(tone);
    if (!mounted) return;
    setState(() => _future = services.ensureLoaded());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لحن مربی: ${tone.labelFa}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل')),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('لحن مربی', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final tone in CoachTone.values)
                Card(
                  child: RadioListTile<CoachTone>(
                    value: tone,
                    groupValue: progress.tone,
                    onChanged: (t) => t != null ? _setTone(t) : null,
                    title: Text(tone.labelFa),
                    subtitle: Text(tone.descFa),
                    activeColor: AppColors.orange,
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'تنظیمات بیشتر (تم دارک/لایت، تقویم شمسی، خروجی گزارش) در فاز P2 اضافه می‌شود.',
                style: TextStyle(color: AppColors.textMutedLight, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}
