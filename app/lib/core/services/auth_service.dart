import '../models/models.dart';
import 'account_repository.dart';
import 'remote_api.dart';

/// سرویس حساب کاربر: ورود/ثبت‌نام با OTP (Mock در توسعه)، خروج.
/// همهٔ داده‌ها در مخزن محلی نگهداری می‌شوند؛ در صورت نبود سرور، اپ مهمان می‌ماند.
class AuthService {
  AuthService({required this.repository, required this.api});

  final AccountRepository repository;
  final RemoteApi api;

  Future<UserAccount?> account() => repository.loadAccount();

  Future<bool> isLoggedIn() async => await repository.loadAccount() != null;

  /// درخواست کد تأیید — در حالت توسعه کد در نتیجه برمی‌گردد.
  Future<OtpRequestResult> requestOtp(String phone) {
    if (!api.enabled) {
      throw const ApiException(0, 'برای ورود به اینترنت نیاز داری');
    }
    return api.requestOtp(phone);
  }

  /// تأیید کد → ساخت حساب (اگر جدید باشد) یا ورود → ذخیرهٔ محلی.
  Future<UserAccount> verifyOtp({
    required String phone,
    required String code,
    String? name,
    AccountRole? role,
  }) async {
    final account = await api.verifyOtp(
      phone: phone,
      code: code,
      name: name,
      role: role,
    );
    await repository.saveAccount(account);
    return account;
  }

  Future<UserAccount> login({
    required String phone,
    required String password,
  }) async {
    final account = await api.login(phone: phone, password: password);
    await repository.saveAccount(account);
    return account;
  }

  /// خروج از حساب: ابطال توکن در سرور (در صورت امکان) + پاک‌کردن حساب و صف محلی.
  Future<void> logout() async {
    final account = await repository.loadAccount();
    if (account != null && api.enabled) {
      try {
        await api.logout(account.refreshToken);
      } catch (_) {
        // آفلاین/خطا: ابطال سمت سرور بعداً لازم نیست؛ توکن کوتاه‌عمر است
      }
    }
    await repository.clearAll();
  }
}
