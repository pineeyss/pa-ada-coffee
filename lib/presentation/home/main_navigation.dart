import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/stock_service.dart';

import '../dashboard/home_screen.dart';
import '../sales/sales_screen.dart';
import '../stock/stock_screen.dart';
import '../reports/reports_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final SupabaseClient supabase = Supabase.instance.client;

  int _selectedIndex = 0;
  bool isLoading = true;
  String role = 'owner';

  List<Widget> _pages = const [];
  List<NavigationDestination> _destinations = const [];

  // =========================
  // 🔥 INIT (STEP 3 MASUK SINI)
  // =========================

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // 🔥 reset stock harian (AUTO)
      await StockService().resetStockIfNewDay();

      // 🔥 lanjut load role & navigation
      await _loadRoleAndSetupNavigation();
    } catch (e) {
      debugPrint('Init app error: $e');
      await _loadRoleAndSetupNavigation();
    }
  }

  // =========================
  // LOAD ROLE
  // =========================

  Future<void> _loadRoleAndSetupNavigation() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          role = 'owner';
          _setupOwnerNavigation();
        });
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final userRole = (profile?['role'] ?? 'owner')
          .toString()
          .toLowerCase();

      if (!mounted) return;

      setState(() {
        role = userRole;
        isLoading = false;

        if (role == 'rider') {
          _setupRiderNavigation();
        } else {
          _setupOwnerNavigation();
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        role = 'owner';
        _setupOwnerNavigation();
      });
    }
  }

  // =========================
  // OWNER NAVIGATION
  // =========================

  void _setupOwnerNavigation() {
    _pages = const [
      HomeScreen(),
      SalesScreen(),
      StockScreen(),
      ReportsScreen(),
      ProfileScreen(),
    ];

    _destinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.shopping_cart_outlined),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Sales',
      ),
      NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Stock',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Reports',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  // =========================
  // RIDER NAVIGATION
  // =========================

  void _setupRiderNavigation() {
    _pages = const [
      HomeScreen(),
      SalesScreen(),
      ReportsScreen(),
      ProfileScreen(),
    ];

    _destinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.shopping_cart_outlined),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Sales',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Reports',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    if (_selectedIndex >= _pages.length) {
      _selectedIndex = 0;
    }
  }

  // =========================
  // NAVIGATION HANDLER
  // =========================

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // =========================
  // UI STYLE
  // =========================

  MaterialStateProperty<IconThemeData?> _iconTheme() {
    return MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const IconThemeData(
          color: Colors.black,
          size: 26,
        );
      }

      return IconThemeData(
        color: Colors.black.withAlpha(160),
        size: 24,
      );
    });
  }

  MaterialStateProperty<TextStyle?> _labelTextStyle() {
    return MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
      }

      return TextStyle(
        color: Colors.black.withAlpha(160),
        fontWeight: FontWeight.w500,
        fontSize: 12,
      );
    });
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: _iconTheme(),
          labelTextStyle: _labelTextStyle(),
        ),
        child: NavigationBar(
          height: 74,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Colors.white,
          indicatorColor: Colors.black.withAlpha(18),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _destinations,
        ),
      ),
    );
  }
}