import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/services/jalali.dart';
import '../../core/services/storage.dart';
import '../../core/services/streak.dart';
import '../../core/theme/app_colors.dart';
import '../search/global_search_button.dart';
import '../venues/venues_screen.dart';
import '../workout/energy_selector.dart';
import '../workout/today_workout_screen.dart';

/// تب خانه — چرخهٔ طلایی: انرژی روز ← تمرین امروز ← شروع تمرین.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<UserProgress> _future;

  @override
  void initState() {
    super.initState();
    _future = BadaneScope.of(context).ensureLoaded();
  }

  void _reload() {
    setState(() {
      _future = BadaneScope.of(context).ensureLoaded();
    });
  }

  Future<void> _selectEnergy(EnergyLevel level) async {
    final services = BadaneScope.of(context);
    await services.progress.setEnergy(level, services.clock.now());
    _reload();
  }

  Future<void> _openWorkout(WorkoutProgram program, ProgramSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TodayWorkoutScreen(program: program, session: session),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بدنه'),
        actions: const [GlobalSearchButton()],
      ),
      body: FutureBuilder<UserProgress>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _reload);
          }
          return _HomeContent(
            progress: snapshot.data!,
            onSelectEnergy: _selectEnergy,
            onOpenWorkout: _openWorkout,
          );
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.progress,
    required this.onSelectEnergy,
    required this.onOpenWorkout,
  });

  final UserProgress progress;
  final ValueChanged<EnergyLevel> onSelectEnergy;
  final void Function(WorkoutProgram program, ProgramSession session)
      onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    final services = BadaneScope.of(context);
    final now = services.clock.now();
    final todayStr = Clock.dateStr(now);
    final doneToday = progress.workouts.any((w) => w.date == todayStr);
    final energySelected = progress.energyDate == todayStr;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GreetingCard(progress: progress, today: now),
        const SizedBox(height: 16),
        if (!energySelected)
          EnergySelector(onSelect: onSelectEnergy)
        else if (!doneToday)
          _TodayWorkoutCard(
            progress: progress,
            onOpen: () {
              final program = _resolveProgram(services);
              onOpenWorkout(program.$1, program.$2);
            },
          )
        else
          _DoneTodayCard(progress: progress),
        const SizedBox(height: 16),
        const _ExploreVenuesCard(),
      ],
    );
  }

  (WorkoutProgram, ProgramSession) _resolveProgram(AppServices services) {
    final isQuick = progress.energyLevel == EnergyLevel.low;
    final programId = isQuick ? 'quick_start' : progress.activeProgramId;
    final program = services.content.programById(programId) ??
        services.content.programs.first;
    final count = progress.workouts
        .where((w) => w.programId == program.id)
        .length;
    final session = program.sessions[count % program.sessions.length];
    return (program, session);
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.progress, required this.today});

  final UserProgress progress;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final streak = _streakOf(progress, today);
    final rank = _rankOf(context, progress);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.orange,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سلام، سازنده!',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'امروز ${JalaliDate.weekdayFa(today)}، ${JalaliDate.fromGregorian(today).formatFa()}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMutedLight),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text('🔥 $streak',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('روز پیوسته',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMutedLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _streakOf(UserProgress p, DateTime now) {
    final dates = p.workouts.map(_dateOf).toList();
    return computeStreak(dates, now);
  }

  static DateTime _dateOf(WorkoutEntry w) {
    final parts = w.date.split('-');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  String _rankOf(BuildContext context, UserProgress p) {
    final ranks = BadaneScope.of(context).content.ranks;
    if (ranks.isEmpty) return '';
    var current = ranks.first;
    for (final r in ranks) {
      if (p.totalPoints >= r.minPoints) current = r;
    }
    return '${current.emoji} ${current.name}';
  }
}

class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard({required this.progress, required this.onOpen});

  final UserProgress progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final services = BadaneScope.of(context);
    final isQuick = progress.energyLevel == EnergyLevel.low;
    final programId = isQuick ? 'quick_start' : progress.activeProgramId;
    final program =
        services.content.programById(programId) ?? services.content.programs.first;
    final count =
        progress.workouts.where((w) => w.programId == program.id).length;
    final session = program.sessions[count % program.sessions.length];

    return Card(
      color: AppColors.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isQuick ? 'تمرین کوتاه امروز ⚡' : 'تمرین امروز',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              '${program.name} — ${session.name}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              '${session.exercises.length} حرکت · ${JalaliDate.faDigits(session.exercises.fold<int>(0, (a, se) => a + se.sets).toString())} ست',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpen,
                child: const Text('شروع تمرین',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneTodayCard extends StatelessWidget {
  const _DoneTodayCard({required this.progress});

  final UserProgress progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: AppColors.successGreen, size: 40),
            const SizedBox(height: 8),
            Text('تمرین امروز انجام شد!', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'مجموع امتیازها: ${JalaliDate.faDigits(progress.totalPoints.toString())}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.orange),
          const SizedBox(height: 12),
          const Text('خطا در بارگذاری داده‌ها'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
        ],
      ),
    );
  }
}

class _ExploreVenuesCard extends StatelessWidget {
  const _ExploreVenuesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.orange,
              child: Icon(Icons.location_on_outlined, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مکان‌های ورزشی نزدیک تو', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                    'استخر، باشگاه، رزمی، یوگا و حرکت اصلاحی — با نقشه نشان در حالت Mock.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMutedLight),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const VenuesScreen()),
              ),
              child: const Text('دیدن'),
            ),
          ],
        ),
      ),
    );
  }
}
