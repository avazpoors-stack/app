import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/content_repository.dart';

const _exercises = '''
[
  {"id":"squat","nameFa":"اسکوات","muscle":"پا","equipment":"بدون وسیله","corrective":false,"tipFa":"تیپ"},
  {"id":"plank","nameFa":"پلانک","muscle":"میان‌تنه","equipment":"بدون وسیله","corrective":false,"tipFa":""}
]
''';

const _programs = '''
[
  {
    "id":"starter","name":"آغاز","level":"beginner","location":"خانه","daysPerWeek":3,
    "focus":"عادت",
    "sessions":[
      {"id":"A","name":"جلسهٔ A","exercises":[
        {"exerciseId":"squat","sets":3,"reps":10,"restSec":60}
      ]}
    ]
  }
]
''';

const _messages = '''
{
  "playful": {"workoutComplete": ["پیام یک", "پیام دو"]},
  "supportive": {"workoutComplete": ["پیام حمایتگر"]}
}
''';

const _ranks = '''
[
  {"name":"نوپا","emoji":"⚪","minPoints":0},
  {"name":"جنگجو","emoji":"🟠","minPoints":500}
]
''';

void main() {
  test('بارگذاری محتوا از JSON', () async {
    final repo = ContentRepository(overrides: {
      'assets/content/exercises.json': _exercises,
      'assets/content/programs.json': _programs,
      'assets/content/messages.json': _messages,
      'assets/content/ranks.json': _ranks,
    });
    await repo.load();

    expect(repo.exercises.length, 2);
    expect(repo.programs.length, 1);
    expect(repo.ranks.length, 2);

    final program = repo.programById('starter');
    expect(program, isNotNull);
    expect(program!.sessions.single.exercises.single.reps, 10);

    expect(repo.exerciseById('squat')!.nameFa, 'اسکوات');
    expect(repo.exerciseById('nothing'), isNull);
  });

  test('انتخاب پیام بر اساس لحن و seed قطعی است', () async {
    final repo = ContentRepository(overrides: {
      'assets/content/exercises.json': _exercises,
      'assets/content/programs.json': _programs,
      'assets/content/messages.json': _messages,
      'assets/content/ranks.json': _ranks,
    });
    await repo.load();

    expect(repo.messageFor(CoachTone.playful, 'workoutComplete', 0), 'پیام یک');
    expect(repo.messageFor(CoachTone.playful, 'workoutComplete', 1), 'پیام دو');
    expect(repo.messageFor(CoachTone.playful, 'workoutComplete', 2), 'پیام یک');
    expect(repo.messageFor(CoachTone.supportive, 'workoutComplete', 0),
        'پیام حمایتگر');
    expect(repo.messageFor(CoachTone.direct, 'workoutComplete', 0), '');
  });
}
