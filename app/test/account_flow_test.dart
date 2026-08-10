import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/account_repository.dart';
import 'package:badane/core/services/auth_service.dart';
import 'package:badane/core/services/remote_api.dart';
import 'package:badane/core/services/storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('ثبت‌نام با OTP: کد توسعه، ذخیرهٔ حساب، ورود و خروج', () async {
    final store = InMemoryStore();
    final api = FakeRemoteApi();
    final auth = AuthService(repository: AccountRepository(store), api: api);

    final result = await auth.requestOtp('09120000001');
    expect(result.mock, true);
    expect(result.code, '123456');

    final account = await auth.verifyOtp(
      phone: '09120000001',
      code: result.code!,
      name: 'سارا',
      role: AccountRole.coach,
    );
    expect(account.role, AccountRole.coach);
    expect(await auth.isLoggedIn(), true);

    // حساب از حافظهٔ محلی دوباره خوانده می‌شود
    final loaded = await auth.account();
    expect(loaded!.phone, '09120000001');
    expect(loaded.name, 'سارا');

    // خروج → پاک‌شدن حساب + ابطال در سرور
    await auth.logout();
    expect(await auth.isLoggedIn(), false);
    expect(api.loggedOut, true);
  });

  test('کد اشتباه → خطا و حساب ذخیره نمی‌شود', () async {
    final api = FakeRemoteApi();
    final auth = AuthService(
      repository: AccountRepository(InMemoryStore()),
      api: api,
    );

    await expectLater(
      auth.verifyOtp(phone: '09120000002', code: '999999'),
      throwsA(isA<ApiException>()),
    );
    expect(await auth.isLoggedIn(), false);
  });

  test('بدون اینترنت → خطای شبکه و حساب مهمان می‌ماند', () async {
    final api = FakeRemoteApi(offline: true);
    final auth = AuthService(
      repository: AccountRepository(InMemoryStore()),
      api: api,
    );

    await expectLater(
      auth.requestOtp('09120000003'),
      throwsA(isA<ApiException>()),
    );
    expect(await auth.isLoggedIn(), false);
  });

  test('ورود با شماره و رمز', () async {
    final api = FakeRemoteApi();
    final auth = AuthService(
      repository: AccountRepository(InMemoryStore()),
      api: api,
    );

    final account = await auth.login(
      phone: '09120000004',
      password: 's3cret-pass-123',
    );
    expect(account.phone, '09120000004');
    expect(await auth.isLoggedIn(), true);
  });
}
