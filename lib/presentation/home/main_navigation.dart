import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _loadRoleAndSetupNavigation();
  }

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

      final userRole = (profile?['role'] ?? 'owner').toString().toLowerCase();

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

  void _setupRiderNavigation() {
    _pages = const [
      HomeScreen(),
      SalesScreen(),
      StockScreen(),
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
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    if (_selectedIndex >= _pages.length) {
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: Colors.white,
        indicatorColor: Colors.orange.withAlpha(22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _destinations,
      ),
    );
  }
}