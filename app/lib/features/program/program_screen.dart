import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/app_colors.dart';

/// تب برنامه — انتخاب برنامهٔ فعال (امکان تغییر سطح، مسترپلن ۲.۲).
class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  late Future<UserProgress> _future;

  @override
  void initState() {
    super.initState();
    _future = BadaneScope.of(context).ensureLoaded();
  }

  Future<void> _select(WorkoutProgram program) async {
    final services = BadaneScope.of(context);
    await services.progress.setActiveProgram(program.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('برنامهٔ «${program.name}» فعال شد')),
    );
    setState(() => _future = services.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('برنامه')),
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
          final programs = BadaneScope.of(context).content.programs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];
              final isActive = program.id == progress.activeProgramId;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isActive ? AppColors.orange : AppColors.surfaceDark,
                    child: isActive
                        ? const Icon(Icons.check, color: Colors.white)
                        : Icon(Icons.fitness_center,
                            color: isActive ? Colors.white : Colors.white70),
                  ),
                  title: Text(program.name),
                  subtitle: Text(
                    '${_levelFa(program.level)} · ${program.location} · ${program.daysPerWeek} روز در هفته\n${program.focus}',
                  ),
                  isThreeLine: true,
                  onTap: isActive ? null : () => _select(program),
                  trailing: isActive
                      ? const Text('فعال', style: TextStyle(color: AppColors.orange))
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _levelFa(String level) => switch (level) {
        'beginner' => 'مبتدی',
        'intermediate' => 'متوسط',
        'all' => 'همه سطوح',
        _ => level,
      };
}
