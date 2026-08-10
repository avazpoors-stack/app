import 'dart:convert';

import '../models/models.dart';
import 'content_repository.dart';
import 'remote_api.dart';
import 'storage.dart';

/// سرویس جستجوی سراسری (P3) — آفلاین-اول، سبک و بدون وابستگی خارجی.
/// UI فقط این سرویس را صدا می‌زند؛ خودش از ذخیره/شبکه خبر ندارد (قرارداد ۲.۵).
class SearchService {
  SearchService({
    required ContentRepository content,
    required KeyValueStore store,
    required RemoteApi api,
  })  : _content = content,
        _store = store,
        _api = api;

  final ContentRepository _content;
  final KeyValueStore _store;
  final RemoteApi _api;

  static const _historyKey = 'badane_search_history.json';
  static const _maxHistory = 10;
  static const _maxQueryLength = 40;

  /// نرمال‌سازی فارسی: ی/ک عربی، ارقام فارسی/عربی، اعراب و فاصله‌های اضافی.
  /// هم کلاینت و هم سرور همین منطق را دارند تا نتیجه‌ها قابل پیش‌بینی باشند.
  static String normalize(String value) {
    var text = value.trim().toLowerCase();
    const replacements = {
      'ي': 'ی',
      'ى': 'ی',
      'ئ': 'ی',
      'ك': 'ک',
      'ۀ': 'ه',
      'ة': 'ه',
      'ؤ': 'و',
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  /// جستجو در محتوای داخلی + اگر سرور فعال بود، ادغام نتیجهٔ آنلاین.
  Future<List<SearchResult>> search(
    String rawQuery, {
    SearchCategory? category,
    int limit = 30,
    bool online = true,
  }) async {
    final query = normalize(rawQuery);
    if (query.length < 2) return const [];
    final safeLimit = limit.clamp(1, 50).toInt();

    await _content.load();
    final scored = <_ScoredResult>[];
    for (final doc in _localDocuments()) {
      if (category != null && doc.result.category != category) continue;
      final score = _score(query, doc);
      if (score > 0) scored.add(_ScoredResult(doc.result, score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.result.title.compareTo(b.result.title);
    });

    final merged = <String, SearchResult>{};
    for (final item in scored.take(safeLimit)) {
      merged[_key(item.result)] = item.result;
    }

    if (online && _api.enabled && merged.length < safeLimit) {
      try {
        final remote = await _api.search(
          query: rawQuery.trim(),
          category: category,
          limit: safeLimit - merged.length,
        );
        for (final result in remote) {
          if (category != null && result.category != category) continue;
          merged.putIfAbsent(_key(result), () => result);
        }
      } on ApiException {
        // آفلاین/خطای سرور نباید جستجوی محلی را خراب کند.
      }
    }

    return merged.values.take(safeLimit).toList(growable: false);
  }

  /// ذخیرهٔ جستجوهای اخیر، فقط روی دستگاه و بدون ارسال به سرور.
  Future<void> rememberQuery(String rawQuery) async {
    final query = rawQuery.trim();
    if (normalize(query).length < 2) return;
    final safe = query.length > _maxQueryLength
        ? query.substring(0, _maxQueryLength)
        : query;
    final items = await history();
    final next = <String>[safe, ...items.where((e) => normalize(e) != normalize(safe))]
        .take(_maxHistory)
        .toList(growable: false);
    await _store.write(_historyKey, jsonEncode(next));
  }

  Future<List<String>> history() async {
    final raw = await _store.read(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<String>()
          .where((e) => normalize(e).length >= 2)
          .take(_maxHistory)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearHistory() => _store.remove(_historyKey);

  List<_SearchDocument> _localDocuments() {
    final docs = <_SearchDocument>[];

    for (final e in _content.exercises) {
      docs.add(_SearchDocument(
        SearchResult(
          id: e.id,
          title: e.nameFa,
          subtitle:
              '${e.muscle} · ${e.equipment}${e.corrective ? ' · حرکت اصلاحی' : ''}',
          category: SearchCategory.exercise,
          source: 'local',
        ),
        '${e.nameFa} ${e.muscle} ${e.equipment} ${e.tipFa} ${e.corrective ? 'اصلاحی corrective' : ''}',
      ));
    }

    for (final p in _content.programs) {
      final sessionNames = p.sessions.map((s) => s.name).join(' ');
      final exerciseNames = p.sessions
          .expand((s) => s.exercises)
          .map((se) => _content.exerciseById(se.exerciseId)?.nameFa ?? se.exerciseId)
          .join(' ');
      docs.add(_SearchDocument(
        SearchResult(
          id: p.id,
          title: p.name,
          subtitle: '${_levelFa(p.level)} · ${p.location} · ${p.daysPerWeek} روز در هفته · ${p.focus}',
          category: SearchCategory.program,
          source: 'local',
        ),
        '${p.name} ${p.level} ${p.location} ${p.focus} $sessionNames $exerciseNames',
      ));
    }

    docs.addAll(_futureModuleDocuments);
    return docs;
  }

  int _score(String query, _SearchDocument doc) {
    final title = normalize(doc.result.title);
    final subtitle = normalize(doc.result.subtitle);
    final text = normalize(doc.keywords);
    if (title == query) return 120;
    if (title.startsWith(query)) return 100;
    if (title.contains(query)) return 85;
    if (subtitle.contains(query)) return 65;
    if (text.contains(query)) return 45;

    final terms = query.split(' ').where((e) => e.isNotEmpty).toList();
    if (terms.length > 1 && terms.every(text.contains)) return 35;
    return 0;
  }

  String _key(SearchResult result) => '${result.category.name}:${result.id}';

  String _levelFa(String level) => switch (level) {
        'beginner' => 'مبتدی',
        'intermediate' => 'متوسط',
        'all' => 'همه سطوح',
        _ => level,
      };
}

class _SearchDocument {
  const _SearchDocument(this.result, this.keywords);

  final SearchResult result;
  final String keywords;
}

class _ScoredResult {
  const _ScoredResult(this.result, this.score);

  final SearchResult result;
  final int score;
}

const _futureModuleDocuments = <_SearchDocument>[
  _SearchDocument(
    SearchResult(
      id: 'product_resistance_band',
      title: 'کش تمرینی',
      subtitle: 'محصول نمونه فروشگاه · تجهیزات تمرین خانه · فاز P5',
      category: SearchCategory.product,
      source: 'mock',
      comingSoon: true,
    ),
    'کش تمرینی کش ورزشی تجهیزات بدنسازی خانه فروشگاه محصول',
  ),
  _SearchDocument(
    SearchResult(
      id: 'product_running_shoes',
      title: 'کفش دویدن',
      subtitle: 'محصول نمونه فروشگاه · کفش ورزشی · فاز P5',
      category: SearchCategory.product,
      source: 'mock',
      comingSoon: true,
    ),
    'کفش دویدن رانینگ فروشگاه محصول ورزشی',
  ),
  _SearchDocument(
    SearchResult(
      id: 'venue_pool_sample',
      title: 'استخر نمونه بدنه',
      subtitle: 'مکان نمونه · دسته استخر · نقشه نشان در فاز P4',
      category: SearchCategory.venue,
      source: 'mock',
      comingSoon: true,
    ),
    'استخر شنا مکان ورزشی نشان باشگاه',
  ),
  _SearchDocument(
    SearchResult(
      id: 'venue_gym_sample',
      title: 'باشگاه بدنسازی نمونه',
      subtitle: 'مکان نمونه · دسته بدنسازی · فاز P4',
      category: SearchCategory.venue,
      source: 'mock',
      comingSoon: true,
    ),
    'باشگاه بدنسازی مکان ورزشی وزنه تمرین',
  ),
  _SearchDocument(
    SearchResult(
      id: 'coach_corrective_sample',
      title: 'مربی حرکت اصلاحی',
      subtitle: 'پروفایل نمونه مربی · برنامه‌دهی در فاز P6',
      category: SearchCategory.coach,
      source: 'mock',
      comingSoon: true,
    ),
    'مربی حرکت اصلاحی پاسچر برنامه تمرین مربی‌هاب',
  ),
  _SearchDocument(
    SearchResult(
      id: 'coach_strength_sample',
      title: 'مربی قدرت و عضله‌سازی',
      subtitle: 'پروفایل نمونه مربی · رزرو در فاز P6',
      category: SearchCategory.coach,
      source: 'mock',
      comingSoon: true,
    ),
    'مربی قدرت عضله سازی بدنسازی برنامه مربی‌هاب',
  ),
];
