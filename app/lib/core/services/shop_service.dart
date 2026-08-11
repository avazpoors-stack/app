import 'dart:convert';
import 'dart:math';

import '../models/models.dart';
import 'account_repository.dart';
import 'remote_api.dart';
import 'search_service.dart';
import 'storage.dart';

/// سرویس فروشگاه P5 — آفلاین-اول، بدون کلید اجباری، Mock کامل.
/// دسته‌بندی 8گانه ورزشی (مثل دیجی‌کالا ولی ورزشی)
class ShopService {
  ShopService({
    required KeyValueStore store,
    required RemoteApi api,
    required AccountRepository account,
  })  : _store = store,
        _api = api,
        _account = account;

  final KeyValueStore _store;
  final RemoteApi _api;
  final AccountRepository _account;

  static const _cartKey = 'badane_cart.json';
  static const _localProductsKey = 'badane_local_products.json';

  static const Map<String, String> categories = {
    'clothing': 'لباس ورزشی',
    'shoes': 'کفش ورزشی',
    'nutrition': 'مکمل و تغذیه',
    'gym': 'تجهیزات بدنسازی',
    'pool': 'لوازم استخر',
    'martial': 'لوازم رزمی',
    'ball': 'توپ و راکت',
    'accessories': 'لوازم جانبی',
  };

  /// لیست دسته‌ها
  List<Map<String, String>> categoryList() {
    return categories.entries
        .map((e) => {'id': e.key, 'label': e.value})
        .toList(growable: false);
  }

  /// لیست محصولات — آفلاین‌اول: Mock + محلی + سرور
  Future<List<Product>> listProducts({
    String? category,
    String? brand,
    String? query,
    int? minPrice,
    int? maxPrice,
    int limit = 50,
  }) async {
    final normalizedQuery = SearchService.normalize(query ?? '');
    final merged = <String, Product>{};

    // Mock
    for (final p in _mockProducts) {
      if (_matches(p, category, brand, normalizedQuery, minPrice, maxPrice)) {
        merged['mock:${p.id}'] = p;
      }
    }

    // محلی (فروشنده)
    for (final p in await _loadLocalProducts()) {
      if (_matches(p, category, brand, normalizedQuery, minPrice, maxPrice)) {
        merged['local:${p.id}'] = p;
      }
    }

    // سرور (اگر آنلاین)
    if (_api.enabled) {
      try {
        final remote = await _api.listProducts(
          category: category,
          brand: brand,
          query: query,
          minPrice: minPrice,
          maxPrice: maxPrice,
          limit: limit,
        );
        for (final p in remote) {
          if (_matches(p, category, brand, normalizedQuery, minPrice, maxPrice)) {
            merged['remote:${p.id}'] = p;
          }
        }
      } catch (_) {
        // آفلاین: فقط Mock + محلی
      }
    }

    final result = merged.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result.take(limit).toList(growable: false);
  }

  /// ثبت محصول جدید توسط فروشنده — اگر آفلاین یا سرور نباشد، محلی pending
  Future<Product> createProduct(ProductDraft draft) async {
    final account = await _account.loadAccount();
    if (_api.enabled && account != null && account.role.name == 'seller') {
      try {
        return await _api.createProduct(
          accessToken: account.accessToken,
          draft: draft,
        );
      } catch (_) {
        // fallback به محلی
      }
    }
    final local = Product.fromDraft(
      draft,
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      sellerId: account?.phone.hashCode ?? 0,
    );
    final locals = await _loadLocalProducts();
    locals.insert(0, local);
    await _saveLocalProducts(locals);
    return local;
  }

  /// سبد خرید — فقط محلی
  Future<List<CartItem>> loadCart() async {
    final raw = await _store.read(_cartKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addToCart(Product product, int quantity) async {
    final cart = await loadCart();
    final idx = cart.indexWhere((c) => c.product.id == product.id);
    if (idx >= 0) {
      final existing = cart[idx];
      cart[idx] = CartItem(product: existing.product, quantity: existing.quantity + quantity);
    } else {
      cart.add(CartItem(product: product, quantity: quantity));
    }
    await _saveCart(cart);
  }

  Future<void> removeFromCart(String productId) async {
    final cart = await loadCart();
    cart.removeWhere((c) => c.product.id == productId);
    await _saveCart(cart);
  }

  Future<void> clearCart() async {
    await _store.remove(_cartKey);
  }

  Future<void> _saveCart(List<CartItem> cart) async {
    await _store.write(_cartKey, jsonEncode(cart.map((c) => c.toJson()).toList()));
  }

  /// سفارش Mock — با idempotency key
  Future<OrderResult> checkout(List<CartItem> cart) async {
    if (cart.isEmpty) throw ArgumentError('سبد خرید خالی است');
    final account = await _account.loadAccount();
    final idempotencyKey = 'chk-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';

    // قیمت از محصول (در حالت واقعی باید از سرور خوانده شود)
    final items = cart
        .map((c) => OrderItemDraft(
              productId: c.product.id,
              quantity: c.quantity,
              priceToman: c.product.priceToman,
            ))
        .toList();

    if (_api.enabled && account != null) {
      try {
        final result = await _api.createOrder(
          accessToken: account.accessToken,
          items: items,
          idempotencyKey: idempotencyKey,
        );
        await clearCart();
        return result;
      } catch (_) {
        // fallback Mock
      }
    }

    // Mock محلی
    final total = items.fold<int>(0, (sum, i) => sum + i.priceToman * i.quantity);
    await clearCart();
    return OrderResult(
      orderId: 'local-$idempotencyKey',
      status: 'payment_pending',
      totalToman: total,
      paymentUrl: null,
    );
  }

  Future<List<Product>> _loadLocalProducts() async {
    final raw = await _store.read(_localProductsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalProducts(List<Product> products) async {
    await _store.write(_localProductsKey, jsonEncode(products.map((p) => p.toJson()).toList()));
  }

  bool _matches(
    Product p,
    String? category,
    String? brand,
    String normalizedQuery,
    int? minPrice,
    int? maxPrice,
  ) {
    if (category != null && category.isNotEmpty && p.category != category) return false;
    if (brand != null && brand.isNotEmpty && p.brand != brand) return false;
    if (minPrice != null && p.priceToman < minPrice) return false;
    if (maxPrice != null && p.priceToman > maxPrice) return false;
    if (normalizedQuery.length >= 2) {
      final text = SearchService.normalize('${p.name} ${p.category} ${p.brand}');
      if (!text.contains(normalizedQuery)) return false;
    }
    return true;
  }
}

// Mock محصولات برای نمایش بدون سرور
const _mockProducts = <Product>[
  Product(
    id: 'mock-shirt',
    sellerId: 0,
    name: 'تی‌شرت تمرینی بدنه',
    category: 'clothing',
    brand: 'بدنه',
    priceToman: 490000,
    stock: 20,
    approved: true,
    source: 'mock',
  ),
  Product(
    id: 'mock-band',
    sellerId: 0,
    name: 'کش تمرینی مقاومتی',
    category: 'gym',
    brand: 'بدنه',
    priceToman: 320000,
    stock: 12,
    approved: true,
    source: 'mock',
  ),
  Product(
    id: 'mock-shoe',
    sellerId: 0,
    name: 'کفش دویدن سبک',
    category: 'shoes',
    brand: 'بدنه',
    priceToman: 2150000,
    stock: 8,
    approved: true,
    source: 'mock',
  ),
  Product(
    id: 'mock-supplement',
    sellerId: 0,
    name: 'شیک پروتئین وی 1kg',
    category: 'nutrition',
    brand: 'بدنه',
    priceToman: 1850000,
    stock: 15,
    approved: true,
    source: 'mock',
  ),
  Product(
    id: 'mock-goggles',
    sellerId: 0,
    name: 'عینک شنا ضدبخار',
    category: 'pool',
    brand: 'Aqua',
    priceToman: 420000,
    stock: 25,
    approved: true,
    source: 'mock',
  ),
  Product(
    id: 'mock-gloves',
    sellerId: 0,
    name: 'دستکش بوکس چرمی',
    category: 'martial',
    brand: 'FightPro',
    priceToman: 890000,
    stock: 6,
    approved: true,
    source: 'mock',
  ),
  Product(
    id: 'mock-ball',
    sellerId: 0,
    name: 'توپ بسکتبال حرفه‌ای',
    category: 'ball',
    brand: 'Spalding',
    priceToman: 1250000,
    stock: 10,
    approved: true,
    source: 'mock',
  ),
  Product(
    id: 'mock-bottle',
    sellerId: 0,
    name: 'قمقمه ورزشی 750ml',
    category: 'accessories',
    brand: 'بدنه',
    priceToman: 180000,
    stock: 40,
    approved: true,
    source: 'mock',
  ),
];
