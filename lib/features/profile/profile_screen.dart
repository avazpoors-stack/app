import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/services/remote_api.dart';
import '../../core/theme/app_colors.dart';
import '../search/global_search_button.dart';

/// تب پروفایل — حساب کاربر (P2)، تنظیمات (لحن، تم)، وضعیت سینک.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProgress> _future;
  int _pendingSync = 0;

  @override
  void initState() {
    super.initState();
    final services = BadaneScope.of(context);
    _future = services.ensureLoaded();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final n = await BadaneScope.of(context).pendingSyncCount();
    if (!mounted) return;
    setState(() => _pendingSync = n);
  }

  Future<void> _reload() async {
    final services = BadaneScope.of(context);
    if (!mounted) return;
    setState(() {
      _future = services.ensureLoaded();
    });
    await _refreshPending();
  }

  Future<void> _setTone(CoachTone tone) async {
    final services = BadaneScope.of(context);
    await services.progress.setTone(tone);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لحن مربی: ${tone.labelFa}')),
    );
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await BadaneScope.of(context).setTheme(mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم: ${_themeLabel(mode)}')),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'روشن',
        ThemeMode.dark => 'تیره',
        _ => 'همراه با سیستم',
      };

  Future<void> _openLoginSheet() async {
    final services = BadaneScope.of(context);
    final account = await showModalBottomSheet<UserAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AuthSheet(),
    );
    if (account != null && mounted) {
      // دادهٔ مهمان (P1) به حساب منتقل می‌شود + سینک اولیه
      try {
        await services.sync.claimGuest();
      } on ApiException {
        // آفلاین: سینک بعداً با دکمهٔ همگام‌سازی انجام می‌شود
      }
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خوش آمدی، ${account.name.isEmpty ? 'کاربر بدنه' : account.name}')),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از حساب'),
        content: const Text('پیشرفت محلی تو (مهمان) می‌ماند؛ فقط حساب و صف سینک پاک می‌شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await BadaneScope.of(context).auth.logout();
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('از حساب خارج شدی؛ پیشرفتت محلی می‌ماند')),
    );
  }

  Future<void> _syncNow() async {
    final services = BadaneScope.of(context);
    final ok = await services.sync.syncNow();
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'همگام‌سازی انجام شد ✅' : 'همگام‌سازی نشد؛ بدون اینترنت یا بدون حساب',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل'),
        actions: const [GlobalSearchButton()],
      ),
      body: FutureBuilder<UserProgress>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final progress = snapshot.data ?? UserProgress();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAccountCard(context),
              const SizedBox(height: 20),
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
              const SizedBox(height: 12),
              Text('تم', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final mode in const [
                      ThemeMode.system,
                      ThemeMode.light,
                      ThemeMode.dark,
                    ])
                      RadioListTile<ThemeMode>(
                        value: mode,
                        groupValue:
                            BadaneScope.of(context).themeMode.value,
                        onChanged: (m) => m != null ? _setTheme(m) : null,
                        title: Text(_themeLabel(mode)),
                        activeColor: AppColors.orange,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSyncCard(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final services = BadaneScope.of(context);
    return FutureBuilder<UserAccount?>(
      future: services.account.loadAccount(),
      builder: (context, snapshot) {
        final account = snapshot.data;
        if (account == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person_off_outlined, size: 40, color: AppColors.textMutedLight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('مهمان', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(
                          'بدون ثبت‌نام هم می‌تونی تمرین کنی. با حساب کاربری، پیشرفتت ذخیره و همگام می‌شود.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMutedLight),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _openLoginSheet,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                    child: const Text('ورود / ثبت‌نام'),
                  ),
                ],
              ),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.orange,
                      child: Text(
                        account.name.isEmpty ? account.phone[0] : account.name[0],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name.isEmpty ? 'کاربر بدنه' : account.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${account.phone} · ${account.role.labelFa}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _syncNow,
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('همگام‌سازی'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('خروج'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_sync_outlined, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pendingSync > 0
                    ? '$_pendingSync تمرین در انتظار همگام‌سازی است'
                    : 'همه‌چیز همگام است (آفلاین-اول: ثبت تمرین بدون اینترنت هم کار می‌کند)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// برگهٔ ورود/ثبت‌نام با OTP — مرحلهٔ ۱: شماره، مرحلهٔ ۲: کد + نام + نقش.
class _AuthSheet extends StatefulWidget {
  const _AuthSheet();

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  AccountRole _role = AccountRole.customer;
  bool _busy = false;
  bool _codeRequested = false;
  String? _devCode;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final phone = _phone.text.trim();
    if (phone.length != 11) {
      setState(() => _error = 'شماره باید ۱۱ رقم باشد (مثل 0912...)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await BadaneScope.of(context).auth.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _devCode = result.code;
        if (result.code != null) _code.text = result.code!;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'کد ۶ رقمی را وارد کن');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await BadaneScope.of(context).auth.verifyOtp(
            phone: phone,
            code: code,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      Navigator.of(context).pop(account);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ورود / ثبت‌نام', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'با شمارهٔ موبایل. کد تأیید (در این نسخهٔ توسعه) همان‌جا نمایش داده می‌شود.',
                style: TextStyle(fontSize: 12, color: AppColors.textMutedLight),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'شماره موبایل',
                  hintText: '0912xxxxxxx',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!_codeRequested)
                FilledButton(
                  onPressed: _busy ? null : _requestCode,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                  child: Text(_busy ? '...' : 'دریافت کد تأیید'),
                )
              else ...[(
                if (_devCode != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'کد (توسعه): $_devCode',
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'کد تأیید',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'نام (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'نقش شما',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AccountRole>(
                      value: _role,
                      isExpanded: true,
                      items: [
                        for (final role in AccountRole.values)
                          DropdownMenuItem(value: role, child: Text(role.labelFa)),
                      ],
                      onChanged: (r) => r != null ? setState(() => _role = r) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _verify,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                  child: Text(_busy ? '...' : 'ورود'),
                ),
              ],
              if (_error != null) ...[(
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
