import 'package:flutter/material.dart';
// Gunakan nama package projectmu (biasanya ad_a_coffee)
import 'package:ad_a_coffee/presentation/dashboard/home_screen.dart';
import 'package:ad_a_coffee/presentation/sales/sales_screen.dart';
import 'package:ad_a_coffee/presentation/reports/reports_screen.dart';
import 'package:ad_a_coffee/presentation/profile/profile_screen.dart';

class RiderNavigation extends StatefulWidget {
  const RiderNavigation({super.key});

  @override
  State<RiderNavigation> createState() => _RiderNavigationState();
}

class _RiderNavigationState extends State<RiderNavigation> {
  int _selectedIndex = 0;

  // JANGAN pakai 'const' di depan kurung siku [
  final List<Widget> _pages = [
    const HomeScreen(),
    const SalesScreen(),
    const ReportsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}