import 'package:flutter/material.dart';

import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/program/program_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/shop/shop_screen.dart';

/// پوستهٔ اصلی اپ: ۵ تب (خانه / برنامه / فروشگاه / پیشرفت / پروفایل)
/// — ساختار ناوبری مسترپلن بخش ۲.۲ + فروشگاه P5
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    ProgramScreen(),
    ShopScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'برنامه',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'فروشگاه',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'پیشرفت',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'پروفایل',
          ),
        ],
      ),
    );
  }
}
