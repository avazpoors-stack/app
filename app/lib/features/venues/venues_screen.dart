import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/services/jalali.dart';
import '../../core/theme/app_colors.dart';
import '../search/global_search_button.dart';
import '../shared/empty_state.dart';

/// فاز P4 — مکان‌های ورزشی + نقشه نشان (placeholder بدون کلید).
class VenuesScreen extends StatefulWidget {
  const VenuesScreen({super.key});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  VenueCategory? _category;
  final _query = TextEditingController();
  late Future<List<Venue>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<List<Venue>> _load() => BadaneScope.of(context).venues.list(
        category: _category,
        query: _query.text,
      );

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openSubmitSheet() async {
    final venue = await showModalBottomSheet<Venue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _VenueSubmitSheet(),
    );
    if (venue == null || !mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«${venue.name}» ثبت شد و در انتظار تأیید است')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = BadaneScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('مکان‌های ورزشی'),
        actions: const [GlobalSearchButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubmitSheet,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('ثبت مکان'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _NeshanMapPlaceholder(enabled: services.venues.neshanConfigured),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'جستجوی مکان، شهر یا آدرس...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'جستجو',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _reload,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: const Text('همه'),
                    selected: _category == null,
                    onSelected: (_) {
                      setState(() => _category = null);
                      _reload();
                    },
                  ),
                ),
                for (final category in VenueCategory.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(category.labelFa),
                      selected: _category == category,
                      onSelected: (_) {
                        setState(() => _category = category);
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Venue>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'مکان‌ها بارگذاری نشد',
                    message: 'داده‌های نمونه و ثبت محلی بدون اینترنت هم کار می‌کند.',
                  );
                }
                final venues = snapshot.data ?? const <Venue>[];
                if (venues.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'مکانی پیدا نشد',
                    message: 'فیلتر را عوض کن یا اولین مکان را ثبت کن.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: venues.length,
                  itemBuilder: (context, index) => _VenueCard(venue: venues[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NeshanMapPlaceholder extends StatelessWidget {
  const _NeshanMapPlaceholder({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceDark,
      child: Container(
        height: 132,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A2A2A), Color(0xFF151515)],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: AppColors.orange, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    enabled ? 'نقشه نشان آماده است' : 'نقشه نشان در حالت Mock',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    enabled
                        ? 'کلید نشان از تنظیمات امن خوانده شده؛ اتصال SDK در همین معماری انجام می‌شود.'
                        : 'فعلاً بدون کلید هم کار می‌کند. آخر پروژه NESHAN_API_KEY را در config وارد می‌کنی.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final tariff = venue.tariffs.isEmpty ? null : venue.tariffs.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                  child: Icon(_icon(venue.category), color: AppColors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(venue.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${venue.category.labelFa}${venue.city.isEmpty ? '' : ' · ${venue.city}'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: venue.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(venue.address, style: const TextStyle(fontSize: 13)),
            if (venue.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                venue.description,
                style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (tariff != null)
                  Expanded(
                    child: Text(
                      '${tariff.title}: ${JalaliDate.faDigits(tariff.priceToman.toString())} تومان',
                      style: const TextStyle(fontSize: 12, color: AppColors.orange),
                    ),
                  )
                else
                  const Expanded(
                    child: Text('تعرفه ثبت نشده', style: TextStyle(fontSize: 12)),
                  ),
                if (venue.lat != null && venue.lng != null)
                  const Icon(Icons.near_me_outlined, size: 18, color: AppColors.textMutedLight),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(VenueCategory category) => switch (category) {
        VenueCategory.pool => Icons.pool,
        VenueCategory.gym => Icons.fitness_center,
        VenueCategory.martialArts => Icons.sports_martial_arts,
        VenueCategory.yoga => Icons.self_improvement,
        VenueCategory.crossfit => Icons.directions_run,
        VenueCategory.ballSports => Icons.sports_soccer,
        VenueCategory.tennis => Icons.sports_tennis,
        VenueCategory.running => Icons.park_outlined,
        VenueCategory.corrective => Icons.healing_outlined,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VenueStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VenueStatus.approved => AppColors.successGreen,
      VenueStatus.pending => AppColors.gold,
      VenueStatus.rejected => Colors.redAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.labelFa, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _VenueSubmitSheet extends StatefulWidget {
  const _VenueSubmitSheet();

  @override
  State<_VenueSubmitSheet> createState() => _VenueSubmitSheetState();
}

class _VenueSubmitSheetState extends State<_VenueSubmitSheet> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _tariffTitle = TextEditingController(text: 'جلسه آزاد');
  final _tariffPrice = TextEditingController();
  VenueCategory _category = VenueCategory.gym;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _phone.dispose();
    _tariffTitle.dispose();
    _tariffPrice.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final address = _address.text.trim();
    if (name.length < 2 || address.length < 5) {
      setState(() => _error = 'نام و آدرس را کامل وارد کن');
      return;
    }
    final price = int.tryParse(_tariffPrice.text.trim().replaceAll(',', '')) ?? 0;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final venue = await BadaneScope.of(context).venues.submit(
            VenueDraft(
              name: name,
              category: _category,
              city: _city.text.trim(),
              address: address,
              phone: _phone.text.trim(),
              description: 'ثبت‌شده از داخل اپ؛ انتشار عمومی بعد از تأیید ادمین.',
              tariffs: price > 0
                  ? [VenueTariff(title: _tariffTitle.text.trim(), priceToman: price)]
                  : const [],
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(venue);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ثبت انجام نشد؛ دوباره تلاش کن');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ثبت مکان ورزشی', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'فعلاً بدون خرید سرور هم به‌صورت محلی ثبت می‌شود؛ انتشار عمومی در سرور نیاز به تأیید ادمین دارد.',
                style: TextStyle(fontSize: 12, color: AppColors.textMutedLight),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'نام مکان', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<VenueCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: 'دسته', border: OutlineInputBorder()),
                items: [
                  for (final category in VenueCategory.values)
                    DropdownMenuItem(value: category, child: Text(category.labelFa)),
                ],
                onChanged: _busy ? null : (v) => v != null ? setState(() => _category = v) : null,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _city,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'شهر', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _address,
                enabled: !_busy,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'آدرس', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'شماره تماس', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tariffTitle,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'عنوان تعرفه', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tariffPrice,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'قیمت تومان', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? '...' : 'ثبت و ارسال برای تأیید'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
