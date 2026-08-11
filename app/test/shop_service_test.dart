import 'package:flutter_test/flutter_test.dart';

import 'package:badane/core/models/models.dart';
import 'package:badane/core/services/account_repository.dart';
import 'package:badane/core/services/shop_service.dart';
import 'package:badane/core/services/storage.dart';

import 'fakes.dart';

void main() {
  test('دسته‌های فروشگاه 8 تا هستند', () {
    final shop = ShopService(
      store: InMemoryStore(),
      api: FakeRemoteApi(),
      account: AccountRepository(InMemoryStore()),
    );
    expect(shop.categoryList(), hasLength(8));
    expect(ShopService.categories.containsKey('gym'), true);
  });

  test('لیست محصولات بدون اینترنت با Mock کار می‌کند', () async {
    final shop = ShopService(
      store: InMemoryStore(),
      api: FakeRemoteApi(offline: true),
      account: AccountRepository(InMemoryStore()),
    );
    final products = await shop.listProducts();
    expect(products.length, greaterThanOrEqualTo(8));
    expect(products.any((p) => p.category == 'gym'), true);
  });

  test('فیلتر دسته', () async {
    final shop = ShopService(
      store: InMemoryStore(),
      api: FakeRemoteApi(offline: true),
      account: AccountRepository(InMemoryStore()),
    );
    final gym = await shop.listProducts(category: 'gym');
    expect(gym.every((p) => p.category == 'gym'), true);
  });

  test('سبد خرید افزودن و حذف', () async {
    final store = InMemoryStore();
    final shop = ShopService(
      store: store,
      api: FakeRemoteApi(),
      account: AccountRepository(store),
    );
    final product = Product(
      id: 'test-1',
      sellerId: 0,
      name: 'دمبل 5kg',
      category: 'gym',
      brand: 'بدنه',
      priceToman: 500000,
      stock: 10,
      approved: true,
    );
    await shop.addToCart(product, 2);
    var cart = await shop.loadCart();
    expect(cart, hasLength(1));
    expect(cart.first.quantity, 2);

    await shop.addToCart(product, 1);
    cart = await shop.loadCart();
    expect(cart.first.quantity, 3);

    await shop.removeFromCart(product.id);
    cart = await shop.loadCart();
    expect(cart, isEmpty);
  });

  test('سفارش Mock و خالی شدن سبد', () async {
    final store = InMemoryStore();
    final shop = ShopService(
      store: store,
      api: FakeRemoteApi(offline: true),
      account: AccountRepository(store),
    );
    final product = Product(
      id: 'test-1',
      sellerId: 0,
      name: 'کش',
      category: 'gym',
      brand: 'بدنه',
      priceToman: 100000,
      stock: 5,
      approved: true,
    );
    await shop.addToCart(product, 2);
    final result = await shop.checkout(await shop.loadCart());
    expect(result.totalToman, 200000);
    expect(result.status, 'payment_pending');
    expect(await shop.loadCart(), isEmpty);
  });

  test('ثبت محصول فروشنده آفلاین محلی', () async {
    final store = InMemoryStore();
    final shop = ShopService(
      store: store,
      api: FakeRemoteApi(offline: true),
      account: AccountRepository(store),
    );
    final draft = ProductDraft(name: 'دمبل نمونه', category: 'gym', brand: 'بدنه', priceToman: 100000, stock: 2);
    final product = await shop.createProduct(draft);
    expect(product.name, 'دمبل نمونه');
    expect(product.approved, false);
  });
}
