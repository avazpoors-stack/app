import 'package:flutter/material.dart';

import 'search_screen.dart';

/// دکمهٔ مشترک جستجوی سراسری برای همهٔ تب‌های اصلی، بدون اضافه‌کردن تب پنجم.
class GlobalSearchButton extends StatelessWidget {
  const GlobalSearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'جستجوی سراسری',
      icon: const Icon(Icons.search),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
      ),
    );
  }
}
