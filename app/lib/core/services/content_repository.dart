import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';

/// بارگذاری محتوای آفلاین از فایل‌های JSON داخل اپ
/// (exercises / programs / messages / ranks — مسترپلن بخش ۸).
class ContentRepository {
  ContentRepository({Map<String, String>? overrides}) : _overrides = overrides;

  final Map<String, String>? _overrides;
  bool _loaded = false;

  List<Exercise> exercises = [];
  List<WorkoutProgram> programs = [];
  Map<String, Map<String, List<String>>> messages = {};
  List<Rank> ranks = [];

  Future<void> load() async {
    if (_loaded) return;
    exercises = _parseExercises(await _read('assets/content/exercises.json'));
    programs = _parsePrograms(await _read('assets/content/programs.json'));
    messages = _parseMessages(await _read('assets/content/messages.json'));
    ranks = _parseRanks(await _read('assets/content/ranks.json'));
    _loaded = true;
  }

  Future<String> _read(String path) async {
    if (_overrides != null) return _overrides![path]!;
    return rootBundle.loadString(path);
  }

  List<Exercise> _parseExercises(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList();

  List<WorkoutProgram> _parsePrograms(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((p) => WorkoutProgram.fromJson(p as Map<String, dynamic>))
          .toList();

  Map<String, Map<String, List<String>>> _parseMessages(String raw) {
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final result = <String, Map<String, List<String>>>{};
    root.forEach((tone, groups) {
      final map = <String, List<String>>{};
      (groups as Map<String, dynamic>).forEach((key, list) {
        map[key] = (list as List<dynamic>).cast<String>();
      });
      result[tone] = map;
    });
    return result;
  }

  List<Rank> _parseRanks(String raw) => (jsonDecode(raw) as List<dynamic>)
      .map((r) => Rank.fromJson(r as Map<String, dynamic>))
      .toList();

  WorkoutProgram? programById(String id) {
    for (final p in programs) {
      if (p.id == id) return p;
    }
    return null;
  }

  Exercise? exerciseById(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// پیام شخصیتی بر اساس لحن و کلید — انتخابی قطعی با seed (قابل تست).
  String messageFor(CoachTone tone, String key, int seed) {
    final list = messages[tone.name]?[key] ?? const <String>[];
    if (list.isEmpty) return '';
    return list[seed % list.length];
  }
}
