import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/app_services.dart';
import '../../core/services/jalali.dart';
import '../../core/theme/app_colors.dart';
import '../search/global_search_button.dart';
import '../shared/empty_state.dart';

/// فروشگاه ورزشی P5 — کاتالوگ 8 دسته، فیلتر، سبد، سفارش Mock
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _category;
  String _query = '';
  final _queryCtrl = TextEditingController();
  late Future<List<Product>> _future;
  late Future<List<CartItem>> _cartFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _cartFuture = _loadCart();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<List<Product>> _load() {
    final shop = BadaneScope.of(context).shop;
    return shop.listProducts(category: _category, query: _query);
  }

  Future<List<CartItem>> _loadCart() {
    return BadaneScope.of(context).shop.loadCart();
  }

  void _reload() {
    setState(() {
      _future = _load();
      _cartFuture = _loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shop = BadaneScope.of(context).shop;
    return Scaffold(
      appBar: AppBar(
        title: const Text('فروشگاه ورزشی'),
        actions: [
          const GlobalSearchButton(),
          FutureBuilder<List<CartItem>>(
            future: _cartFuture,
            builder: (context, snapshot) {
              final count = snapshot.data?.fold<int>(0, (s, c) => s + c.quantity) ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                      _reload();
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                        child: Text(
                          JalaliDate.faDigits(count.toString()),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _queryCtrl,
              onSubmitted: (v) {
                _query = v;
                _reload();
              },
              decoration: InputDecoration(
                hintText: 'جستجوی کفش، لباس، مکمل...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _query = _queryCtrl.text;
                    _reload();
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                    onSelected: (_) {
                      setState(() => _category = null);
                      _reload();
                    },
                  ),
                ),
                for (final cat in shop.categoryList())
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(cat['label']!),
                      selected: _category == cat['id'],
                      onSelected: (_) {
                        setState(() => _category = cat['id']);
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'فروشگاه بارگذاری نشد',
                    message: 'محصولات نمونه بدون اینترنت هم کار می‌کنند.',
                  );
                }
                final products = snapshot.data ?? const <Product>[];
                if (products.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'محصولی پیدا نشد',
                    message: 'فیلتر را عوض کن یا دستهٔ دیگری را انتخاب کن.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _ProductCard(product: products[index], onAdded: _reload),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // پنل فروشنده ساده
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (_) => const _SellerSheet(),
          ).then((_) => _reload());
        },
        icon: const Icon(Icons.storefront_outlined),
        label: const Text('ثبت محصول'),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdded});

  final Product product;
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context) {
    final shop = BadaneScope.of(context).shop;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 92,
            color: AppColors.orange.withValues(alpha: 0.12),
            child: const Icon(Icons.shopping_bag_outlined, size: 42, color: AppColors.orange),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(product.brand.isEmpty ? shop.categories[product.category] ?? product.category : product.brand,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
                const SizedBox(height: 6),
                Text('${JalaliDate.faDigits(product.priceToman.toString())} تومان',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange, fontSize: 12)),
                const SizedBox(height: 2),
                Text('موجودی: ${JalaliDate.faDigits(product.stock.toString())}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMutedLight)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await shop.addToCart(product, 1);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('«${product.name}» به سبد اضافه شد')),
                        );
                      }
                      onAdded();
                    },
                    child: const Text('افزودن', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<CartItem>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CartItem>> _load() => BadaneScope.of(context).shop.loadCart();

  void _reload() => setState(() => _future = _load());

  Future<void> _checkout() async {
    setState(() => _busy = true);
    try {
      final cart = await BadaneScope.of(context).shop.loadCart();
      final result = await BadaneScope.of(context).shop.checkout(cart);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('سفارش ثبت شد: ${result.orderId} - ${JalaliDate.faDigits(result.totalToman.toString())} تومان (Mock)')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سبد خرید')),
      body: FutureBuilder<List<CartItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final cart = snapshot.data ?? const <CartItem>[];
          if (cart.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'سبد خرید خالی است',
              message: 'از فروشگاه محصول اضافه کن.',
            );
          }
          final total = cart.fold<int>(0, (s, c) => s + c.product.priceToman * c.quantity);
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.product.name),
                        subtitle: Text('${JalaliDate.faDigits(item.quantity.toString())} × ${JalaliDate.faDigits(item.product.priceToman.toString())}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await BadaneScope.of(context).shop.removeFromCart(item.product.id);
                            _reload();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('مجموع: ${JalaliDate.faDigits(total.toString())} تومان', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _checkout,
                      child: Text(_busy ? '...' : 'ثبت سفارش Mock'),
                    ),
                    const SizedBox(height: 6),
                    const Text('پرداخت در این نسخه Mock است و نیاز به خرید درگاه در فاز آخر دارد.', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SellerSheet extends StatefulWidget {
  const _SellerSheet();

  @override
  State<_SellerSheet> createState() => _SellerSheetState();
}

class _SellerSheetState extends State<_SellerSheet> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  String _category = 'gym';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'نام محصول را وارد کن');
      return;
    }
    final price = int.tryParse(_price.text.trim()) ?? 0;
    final stock = int.tryParse(_stock.text.trim()) ?? 0;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await BadaneScope.of(context).shop.createProduct(
            ProductDraft(
              name: _name.text.trim(),
              category: _category,
              brand: _brand.text.trim(),
              priceToman: price,
              stock: stock,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('محصول ثبت شد (در انتظار تأیید)')));
    } catch (e) {
      setState(() => _error = 'خطا: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = BadaneScope.of(context).shop;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ثبت محصول جدید', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('فعلاً محلی ذخیره می‌شود، انتشار عمومی بعد از تأیید ادمین.', style: TextStyle(fontSize: 12, color: AppColors.textMutedLight)),
              const SizedBox(height: 14),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'نام محصول', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'دسته', border: OutlineInputBorder()),
                items: [
                  for (final c in shop.categoryList())
                    DropdownMenuItem(value: c['id'], child: Text(c['label']!)),
                ],
                onChanged: (v) => v != null ? setState(() => _category = v) : null,
              ),
              const SizedBox(height: 10),
              TextField(controller: _brand, decoration: const InputDecoration(labelText: 'برند', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت تومان', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'موجودی', border: OutlineInputBorder()))),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 14),
              FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? '...' : 'ثبت')),
            ],
          ),
        ),
      ),
    );
  }
}
