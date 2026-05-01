import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/header.dart';
import '../../data/services/stock_service.dart';
import '../../utils/currency_formatter.dart';
import '../../core/supabase/selected_gerobak_store.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StockService _stockService = StockService();
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  int lowStockCount = 0;
  int totalRevenue = 0;
  int totalOrders = 0;
  List<Map<String, dynamic>> topSellingItems = [];
  List<Map<String, dynamic>> recentSales = [];

  String? selectedGerobakId;
  List<Map<String, dynamic>> gerobakOptions = [];
  String _role = 'owner';

  bool get _isRider => _role == 'rider';

  @override
  void initState() {
    super.initState();
    SelectedGerobakStore.selectedGerobak.addListener(_handleSelectedGerobakChanged);
    SelectedGerobakStore.salesRefreshToken.addListener(_handleSalesChanged);
    initDashboard();
  }

  @override
  void dispose() {
    SelectedGerobakStore.selectedGerobak.removeListener(_handleSelectedGerobakChanged);
    SelectedGerobakStore.salesRefreshToken.removeListener(_handleSalesChanged);
    super.dispose();
  }

  void _handleSelectedGerobakChanged() {
    final newId = SelectedGerobakStore.selectedGerobakId;
    if (newId == null || newId == selectedGerobakId) return;
    if (!mounted) return;
    setState(() => selectedGerobakId = newId);
    loadDashboard();
  }

  void _handleSalesChanged() {
    if (!mounted || selectedGerobakId == null) return;
    loadDashboard();
  }

  // --- LOGIKA RESET STOK HARIAN ---
  Future<void> _checkAndResetStock() async {
    if (selectedGerobakId == null) return;
    try {
      await supabase
          .from('stok_gerobak')
          .update({'stok_saat_ini': 10})
          .eq('gerobak_id', selectedGerobakId!);
    } catch (e) {
      debugPrint("Gagal reset stok: $e");
    }
  }

  Future<void> initDashboard() async {
    try {
      if (mounted) setState(() => isLoading = true);

      final role = await _stockService.getCurrentUserRole();
      final gerobaks = await _stockService.getGerobakOptionsByRole();

      if (gerobaks.isEmpty) {
        if (!mounted) return;
        setState(() {
          _role = role;
          isLoading = false;
          errorMessage = 'Data gerobak kosong';
        });
        return;
      }

      final savedId = SelectedGerobakStore.selectedGerobakId;
      var selected = gerobaks.first;
      if (savedId != null) {
        selected = gerobaks.firstWhere((item) => item['id']?.toString() == savedId, orElse: () => gerobaks.first);
      }

      SelectedGerobakStore.setGerobak(GerobakItem.fromMap(selected));

      if (!mounted) return;
      setState(() {
        _role = role;
        gerobakOptions = gerobaks;
        selectedGerobakId = selected['id']?.toString();
      });

      // Panggil Reset Stok di sini
      await _checkAndResetStock();
      await loadDashboard();
    } catch (e) {
      if (mounted) setState(() { isLoading = false; errorMessage = 'Gagal load data: $e'; });
    }
  }

  Future<void> loadDashboard() async {
    if (selectedGerobakId == null) return;

    try {
      if (mounted) setState(() => isLoading = true);

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      // Query Transaksi Hari Ini
      final transaksi = await supabase
          .from('transaksi')
          .select('id, total_harga, tanggal')
          .eq('gerobak_id', selectedGerobakId!)
          .gte('tanggal', startOfDay)
          .lte('tanggal', endOfDay)
          .order('tanggal', ascending: false);

      int revenue = 0;
      for (final item in transaksi) {
        revenue += ((item['total_harga'] ?? 0) as num).toInt();
      }

      // Ambil Top Selling (Sample 100 transaksi terakhir agar list tidak kosong)
      final allTrx = await supabase.from('transaksi').select('id').eq('gerobak_id', selectedGerobakId!).limit(100);
      
      final topItems = await _getTopSellingItemsFromTransaksi(allTrx);
      final recent = await _getRecentSalesFromTransaksi(transaksi);

      if (!mounted) return;
      setState(() {
        totalRevenue = revenue;
        totalOrders = transaksi.length;
        topSellingItems = topItems;
        recentSales = recent;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> _getTopSellingItemsFromTransaksi(List<dynamic> transaksi) async {
    if (transaksi.isEmpty) return [];
    try {
      final ids = transaksi.map((item) => item['id']).toList();
      final details = await supabase.from('detail_transaksi').select('qty, menu(name)').inFilter('transaksi_id', ids);
      
      final Map<String, int> grouped = {};
      for (final raw in details) {
        final name = raw['menu']['name'].toString();
        grouped[name] = (grouped[name] ?? 0) + ((raw['qty'] ?? 0) as num).toInt();
      }

      final result = grouped.entries.map((e) => {'name': e.key, 'qty': e.value}).toList();
      result.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
      return result;
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> _getRecentSalesFromTransaksi(List<dynamic> transaksi) async {
    if (transaksi.isEmpty) return [];
    try {
      final latest = transaksi.take(6).toList();
      final ids = latest.map((item) => item['id']).toList();
      final details = await supabase.from('detail_transaksi').select('transaksi_id, menu(name)').inFilter('transaksi_id', ids);

      final Map<String, String> menuNames = {};
      for (final d in details) {
        menuNames[d['transaksi_id'].toString()] = d['menu']['name'].toString();
      }

      return latest.map<Map<String, dynamic>>((trx) {
        return {
          'menu_name': menuNames[trx['id'].toString()] ?? '-',
          'total_harga': ((trx['total_harga'] ?? 0) as num).toInt(),
        };
      }).toList();
    } catch (_) { return []; }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              AppHeader(
                subtitle: "Ringkasan Hari Ini",
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedGerobakId,
                      isExpanded: true,
                      items: gerobakOptions.map((item) => DropdownMenuItem(value: item['id'].toString(), child: Text(item['nama_gerobak']))).toList(),
                      onChanged: (v) { setState(() => selectedGerobakId = v); loadDashboard(); },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _miniStat("Sales", CurrencyFormatter.format(totalRevenue), Icons.payments)),
                        const SizedBox(width: 12),
                        Expanded(child: _miniStat("Orders", "$totalOrders", Icons.receipt_long)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      "Top Selling Items",
                      topSellingItems.isEmpty
                          ? const Center(child: Text("Belum ada data"))
                          : Column(
                              children: topSellingItems.take(5).toList().asMap().entries.map((entry) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      CircleAvatar(radius: 12, backgroundColor: Colors.orange, child: Text("${entry.key + 1}", style: const TextStyle(color: Colors.white, fontSize: 12))),
                                      const SizedBox(width: 12),
                                      Text(entry.value['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      "Recent Sales",
                      recentSales.isEmpty
                          ? const EmptyState(icon: Icons.history, title: "Belum ada transaksi", subtitle: "Transaksi hari ini akan muncul di sini.")
                          : Column(
                              children: recentSales.map((sale) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.shopping_bag, color: Colors.orange),
                                  title: Text(sale['menu_name']),
                                  trailing: Text(CurrencyFormatter.format(sale['total_harga']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}