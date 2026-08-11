import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/services/jalali.dart';
import '../../core/theme/app_colors.dart';
import 'workout_summary_screen.dart';

/// صفحهٔ اجرای تمرین امروز: ثبت ست با یک دست + تایمر استراحت + پایان تمرین.
class TodayWorkoutScreen extends StatefulWidget {
  const TodayWorkoutScreen({
    super.key,
    required this.program,
    required this.session,
  });

  final WorkoutProgram program;
  final ProgramSession session;

  @override
  State<TodayWorkoutScreen> createState() => _TodayWorkoutScreenState();
}

class _TodayWorkoutScreenState extends State<TodayWorkoutScreen> {
  final Map<String, Set<int>> _loggedSets = {}; // exerciseId -> ست‌های ثبت‌شده
  Timer? _restTimer;
  int _restRemainingSec = 0;
  bool _finished = false;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  bool _isLogged(String exerciseId, int setIndex) =>
      _loggedSets[exerciseId]?.contains(setIndex) ?? false;

  bool get _allDone => widget.session.exercises.every((se) {
        final logged = _loggedSets[se.exerciseId]?.length ?? 0;
        return logged >= se.sets;
      });

  int get _totalSetsLogged => widget.session.exercises.fold(
      0, (sum, se) => sum + (_loggedSets[se.exerciseId]?.length ?? 0));

  void _startRest(int seconds) {
    _restTimer?.cancel();
    if (seconds <= 0) return;
    setState(() => _restRemainingSec = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restRemainingSec <= 1) {
        timer.cancel();
        if (mounted) setState(() => _restRemainingSec = 0);
      } else {
        setState(() => _restRemainingSec -= 1);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restRemainingSec = 0);
  }

  void _logSet(SessionExercise se, int setIndex) {
    if (_finished) return;
    final logged = _loggedSets.putIfAbsent(se.exerciseId, () => <int>{});
    if (logged.contains(setIndex)) return; // محافظت از کلیک دوباره (Debounce)
    logged.add(setIndex);
    setState(() {});
    _startRest(se.restSec);
  }

  Future<void> _finishWorkout() async {
    if (!_allDone || _finished) return;
    _finished = true;
    _restTimer?.cancel();
    final services = BadaneScope.of(context);
    final progress = await services.progress.load();
    final result = await services.progress.completeWorkout(
      programId: widget.program.id,
      sessionId: widget.session.id,
      setsLogged: _totalSetsLogged,
      exercisesCompleted: widget.session.exercises.length,
      ranks: services.content.ranks,
      now: services.clock.now(),
    );
    final message = services.content.messageFor(
      progress.tone,
      'workoutComplete',
      progress.workouts.length,
    );
    // صف سینک (P2): رکورد تمرین برای همگام‌سازی آفلاین-اول؛
    // اگر حساب/اینترنت نباشد در صف محلی می‌ماند (آفلاین-اول).
    try {
      await services.sync.recordWorkout(
        programId: widget.program.id,
        sessionId: widget.session.id,
        points: result.earned,
      );
    } catch (_) {
      // صف محلی ذخیره شده؛ همگام‌سازی بعداً انجام می‌شود
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutSummaryScreen(
          result: result,
          message: message,
          programName: widget.program.name,
          sessionName: widget.session.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تمرین امروز')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '${widget.program.name} — ${widget.session.name}',
              style: textTheme.titleMedium,
            ),
          ),
          if (_restRemainingSec > 0) _RestBanner(
            remaining: _restRemainingSec,
            onSkip: _skipRest,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.session.exercises.length,
              itemBuilder: (context, index) {
                final se = widget.session.exercises[index];
                final exercise =
                    BadaneScope.of(context).content.exerciseById(se.exerciseId);
                return _ExerciseCard(
                  name: exercise?.nameFa ?? se.exerciseId,
                  muscle: exercise?.muscle ?? '',
                  equipment: exercise?.equipment ?? '',
                  tip: exercise?.tipFa ?? '',
                  corrective: exercise?.corrective ?? false,
                  sessionExercise: se,
                  isLogged: _isLogged,
                  onLogSet: _logSet,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _allDone && !_finished ? _finishWorkout : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _allDone ? 'پایان تمرین 🎉' : 'همهٔ ست‌ها را ثبت کن',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.remaining, required this.onSkip});

  final int remaining;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text('استراحت: ${JalaliDate.faDigits(remaining.toString())} ثانیه'),
          ),
          TextButton(onPressed: onSkip, child: const Text('رد شدن')),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.name,
    required this.muscle,
    required this.equipment,
    required this.tip,
    required this.corrective,
    required this.sessionExercise,
    required this.isLogged,
    required this.onLogSet,
  });

  final String name;
  final String muscle;
  final String equipment;
  final String tip;
  final bool corrective;
  final SessionExercise sessionExercise;
  final bool Function(String exerciseId, int setIndex) isLogged;
  final void Function(SessionExercise se, int setIndex) onLogSet;

  @override
  Widget build(BuildContext context) {
    final se = sessionExercise;
    final allLogged = List.generate(se.sets, (i) => i + 1)
        .every((i) => isLogged(se.exerciseId, i));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (corrective)
                  Chip(
                    label: const Text('اصلاحی'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.successGreen.withOpacity(0.15),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$muscle${equipment.isNotEmpty ? ' · $equipment' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMutedLight),
            ),
            if (tip.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('💡 $tip', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 1; i <= se.sets; i++) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: allLogged
                          ? null
                          : () => onLogSet(se, i),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isLogged(se.exerciseId, i)
                            ? AppColors.successGreen
                            : AppColors.orange,
                        side: BorderSide(
                          color: isLogged(se.exerciseId, i)
                              ? AppColors.successGreen
                              : AppColors.orange.withOpacity(0.5),
                        ),
                      ),
                      child: isLogged(se.exerciseId, i)
                          ? const Icon(Icons.check, size: 18)
                          : Text('ست $i · ${JalaliDate.faDigits(se.reps.toString())} تکرار'),
                    ),
                  ),
                  if (i != se.sets) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
