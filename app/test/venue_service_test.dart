import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/account_repository.dart';
import 'package:badane/core/services/app_services.dart';
import 'package:badane/core/services/storage.dart';

import 'fakes.dart';

void main() {
  test('دسته‌های مکان طبق P4 جدا هستند', () {
    expect(VenueCategory.values.length, 9);
    expect(VenueCategory.pool.labelFa, 'استخر');
    expect(VenueCategory.corrective.apiName, 'corrective');
    expect(VenueCategoryX.fromName('martial_arts'), VenueCategory.martialArts);
  });

  test('لیست مکان‌ها بدون کلید و اینترنت با Mock کار می‌کند', () async {
    final services = AppServices.forTesting(store: InMemoryStore());

    final all = await services.venues.list();
    expect(all.any((v) => v.category == VenueCategory.pool), isTrue);

    final gyms = await services.venues.list(category: VenueCategory.gym);
    expect(gyms, isNotEmpty);
    expect(gyms.every((v) => v.category == VenueCategory.gym), isTrue);
  });

  test('ثبت مکان در حالت آفلاین محلی و pending ذخیره می‌شود', () async {
    final store = InMemoryStore();
    final services = AppServices.forTesting(store: store);

    final venue = await services.venues.submit(
      const VenueDraft(
        name: 'باشگاه تست محلی',
        category: VenueCategory.gym,
        city: 'تهران',
        address: 'خیابان تست، پلاک ۱',
        tariffs: [VenueTariff(title: 'جلسه آزاد', priceToman: 100000)],
      ),
    );

    expect(venue.status, VenueStatus.pending);
    final local = await services.venues.list(query: 'محلی');
    expect(local.any((v) => v.name == 'باشگاه تست محلی'), isTrue);
  });

  test('اگر API و حساب فعال باشد، ثبت مکان به سرور فرستاده می‌شود', () async {
    final store = InMemoryStore();
    final api = FakeRemoteApi();
    final account = AccountRepository(store);
    await account.saveAccount(
      const UserAccount(
        phone: '09120000000',
        name: 'مالک مکان',
        role: AccountRole.venue,
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    final services = AppServices.forTesting(store: store, api: api);

    final venue = await services.venues.submit(
      const VenueDraft(
        name: 'استخر آنلاین',
        category: VenueCategory.pool,
        address: 'آدرس تست آنلاین',
      ),
    );

    expect(venue.id, 'remote-1');
    expect(api.createdVenues.single.name, 'استخر آنلاین');
  });
}
