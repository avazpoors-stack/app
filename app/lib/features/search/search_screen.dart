import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../shared/empty_state.dart';

/// صفحهٔ جستجوی سراسری (P3): حرکات، برنامه‌ها، فروشگاه، مکان‌ها و مربی‌ها.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late Future<List<String>> _historyFuture;
  Future<List<SearchResult>> _resultsFuture = Future.value(const []);
  SearchCategory? _category;
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _historyFuture = Future.value(const []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = BadaneScope.of(context);
      setState(() {
        _historyFuture = services.search.history();
      });
      if (_controller.text.trim().isNotEmpty) {
        _runSearch(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(value));
  }

  Future<void> _submit(String value) async {
    final services = BadaneScope.of(context);
    await services.search.rememberQuery(value);
    if (!mounted) return;
    setState(() {
      _historyFuture = services.search.history();
    });
    _runSearch(value);
  }

  void _runSearch(String rawQuery) {
    final query = rawQuery.trim();
    final services = BadaneScope.of(context);
    setState(() {
      _lastQuery = query;
      _resultsFuture = services.search.search(query, category: _category);
    });
  }

  void _selectCategory(SearchCategory? category) {
    setState(() {
      _category = category;
    });
    _runSearch(_controller.text);
  }

  Future<void> _clearHistory() async {
    final services = BadaneScope.of(context);
    await services.search.clearHistory();
    if (!mounted) return;
    setState(() {
      _historyFuture = services.search.history();
    });
  }

  Future<void> _openResult(SearchResult result) async {
    await BadaneScope.of(context).search.rememberQuery(_controller.text);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ResultSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جستجوی سراسری')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'مثلاً اسکوات، استخر، کفش، مربی...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'پاک کردن',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: const Text('همه'),
                    selected: _category == null,
                    onSelected: (_) => _selectCategory(null),
                  ),
                ),
                for (final category in SearchCategory.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(category.labelFa),
                      selected: _category == category,
                      onSelected: (_) => _selectCategory(category),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _lastQuery.isEmpty
                ? _HistoryAndHints(
                    historyFuture: _historyFuture,
                    onTapHistory: (query) {
                      _controller.text = query;
                      _submit(query);
                    },
                    onClearHistory: _clearHistory,
                  )
                : FutureBuilder<List<SearchResult>>(
                    future: _resultsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const EmptyState(
                          icon: Icons.wifi_off_outlined,
                          title: 'جستجو کامل نشد',
                          message: 'نتیجه‌های محلی همیشه کار می‌کنند؛ دوباره تلاش کن.',
                        );
                      }
                      final results = snapshot.data ?? const [];
                      if (results.isEmpty) {
                        return EmptyState(
                          icon: Icons.search_off,
                          title: 'چیزی پیدا نشد',
                          message: 'یک کلمهٔ دیگر امتحان کن یا فیلتر را روی «همه» بگذار.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (context, index) => _ResultTile(
                          result: results[index],
                          onTap: () => _openResult(results[index]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryAndHints extends StatelessWidget {
  const _HistoryAndHints({
    required this.historyFuture,
    required this.onTapHistory,
    required this.onClearHistory,
  });

  final Future<List<String>> historyFuture;
  final ValueChanged<String> onTapHistory;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: historyFuture,
      builder: (context, snapshot) {
        final history = snapshot.data ?? const <String>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.offline_bolt_outlined, color: AppColors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'جستجو آفلاین هم کار می‌کند؛ اگر سرور وصل باشد نتیجه‌های آنلاین هم اضافه می‌شوند.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('جستجوهای اخیر', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(onPressed: onClearHistory, child: const Text('پاک کردن')),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final query in history)
                    ActionChip(
                      label: Text(query),
                      avatar: const Icon(Icons.history, size: 18),
                      onPressed: () => onTapHistory(query),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('پیشنهاد سریع', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final query in const ['اسکوات', 'شروع کوتاه', 'کش تمرینی', 'استخر', 'مربی اصلاحی'])
                  ActionChip(label: Text(query), onPressed: () => onTapHistory(query)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.orange.withValues(alpha: 0.12),
          child: Icon(_icon(result.category), color: AppColors.orange),
        ),
        title: Text(result.title),
        subtitle: Text(result.subtitle),
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Badge(label: result.category.labelFa),
            if (result.comingSoon) const _Badge(label: 'به‌زودی'),
            const Icon(Icons.chevron_left),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _icon(SearchCategory category) => switch (category) {
        SearchCategory.exercise => Icons.fitness_center,
        SearchCategory.program => Icons.calendar_month_outlined,
        SearchCategory.product => Icons.shopping_bag_outlined,
        SearchCategory.venue => Icons.location_on_outlined,
        SearchCategory.coach => Icons.sports_outlined,
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.orange),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(result.subtitle),
            const SizedBox(height: 12),
            Text(
              result.comingSoon
                  ? 'این بخش برای اتصال کامل در فاز مربوطه آماده شده و فعلاً پیش‌نمایش Mock است.'
                  : 'این نتیجه از محتوای آفلاین اپ آمده و بدون اینترنت هم قابل پیدا شدن است.',
              style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('باشه'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
