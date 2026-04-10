import 'package:flutter/material.dart';

import '../dashboard/home_screen.dart';
import '../sales/sales_screen.dart';
import '../stock/stock_screen.dart';
import '../reports/reports_screen.dart';
import '../profile/profile_screen.dart';

class RiderNavigation extends StatefulWidget {
  const RiderNavigation({super.key});

  @override
  State<RiderNavigation> createState() => _RiderNavigationState();
}

class _RiderNavigationState extends State<RiderNavigation> {
  int index = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const SalesScreen(),
    const StockScreen(),
    const ReportsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Sales",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: "Stock",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Reports",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}