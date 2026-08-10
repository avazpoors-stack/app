import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/app_services.dart';
import 'package:badane/core/services/search_service.dart';
import 'package:badane/core/services/storage.dart';

import 'fakes.dart';

const searchTestContent = {
  'assets/content/exercises.json': '''
[
  {"id":"squat","nameFa":"اسکوات","muscle":"پا","equipment":"بدون وسیله","corrective":false,"tipFa":"زانو هم‌راستا با پنجه"},
  {"id":"corrective_wall","nameFa":"فرشته دیواری","muscle":"شانه","equipment":"دیوار","corrective":true,"tipFa":"برای حرکت اصلاحی شانه"}
]
''',
  'assets/content/programs.json': '''
[
  {
    "id":"starter","name":"آغاز","level":"beginner","location":"خانه","daysPerWeek":3,
    "focus":"عادت‌سازی",
    "sessions":[
      {"id":"A","name":"جلسهٔ A","exercises":[
        {"exerciseId":"squat","sets":3,"reps":10,"restSec":60}
      ]}
    ]
  },
  {
    "id":"quick_start","name":"شروع کوتاه","level":"all","location":"همه‌جا","daysPerWeek":7,
    "focus":"۱۰ دقیقه‌ای",
    "sessions":[
      {"id":"Q","name":"جلسهٔ سریع","exercises":[
        {"exerciseId":"corrective_wall","sets":2,"reps":8,"restSec":30}
      ]}
    ]
  }
]
''',
  'assets/content/messages.json': '''
{"supportive": {"workoutComplete": ["آفرین"]}}
''',
  'assets/content/ranks.json': '''
[{"name":"نوپا","emoji":"⚪","minPoints":0}]
''',
};

void main() {
  test('نرمال‌سازی جستجو ی/ک عربی و فاصله را یکسان می‌کند', () {
    expect(SearchService.normalize('  اسكوات  '), 'اسکوات');
    expect(SearchService.normalize('شروع   كوتاه'), 'شروع کوتاه');
  });

  test('جستجوی آفلاین حرکات، برنامه‌ها و پیش‌نمایش فازهای بعد را پیدا می‌کند', () async {
    final services = AppServices.forTesting(
      contentOverrides: searchTestContent,
      store: InMemoryStore(),
    );
    await services.ensureLoaded();

    final exerciseResults = await services.search.search('اسکوات');
    expect(exerciseResults.first.title, 'اسکوات');
    expect(exerciseResults.first.category, SearchCategory.exercise);

    final programResults = await services.search.search('شروع کوتاه');
    expect(programResults.any((r) => r.id == 'quick_start'), isTrue);

    final productResults = await services.search.search(
      'کش',
      category: SearchCategory.product,
    );
    expect(productResults.single.category, SearchCategory.product);
    expect(productResults.single.comingSoon, isTrue);
  });

  test('نتیجهٔ آنلاین با نتیجهٔ محلی ادغام و تکراری حذف می‌شود', () async {
    final api = FakeRemoteApi(searchResults: const [
      SearchResult(
        id: 'coach_remote_1',
        title: 'مربی آنلاین قدرت',
        subtitle: 'نتیجه آنلاین تست',
        category: SearchCategory.coach,
        source: 'remote',
      ),
    ]);
    final services = AppServices.forTesting(
      contentOverrides: searchTestContent,
      store: InMemoryStore(),
      api: api,
    );
    await services.ensureLoaded();

    final results = await services.search.search('مربی');
    expect(results.any((r) => r.id == 'coach_remote_1'), isTrue);
    expect(results.where((r) => r.id == 'coach_remote_1').length, 1);
  });

  test('تاریخچهٔ جستجو فقط روی دستگاه نگه داشته می‌شود و تکراری نمی‌شود', () async {
    final services = AppServices.forTesting(
      contentOverrides: searchTestContent,
      store: InMemoryStore(),
    );

    await services.search.rememberQuery('اسکوات');
    await services.search.rememberQuery('کش تمرینی');
    await services.search.rememberQuery('اسكوات');

    final history = await services.search.history();
    expect(history.length, 2);
    expect(SearchService.normalize(history.first), 'اسکوات');
  });
}
