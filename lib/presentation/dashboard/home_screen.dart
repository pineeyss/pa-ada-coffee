import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/header.dart';
import '../../data/services/report_service.dart';
import '../../data/services/stock_service.dart';
import '../sales/sales_screen.dart';
import '../reports/reports_screen.dart';
import '../../utils/currency_formatter.dart';
import '../../core/supabase/selected_gerobak_store.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ReportService _reportService = ReportService();
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

  String get _selectedGerobakName {
    if (gerobakOptions.isEmpty || selectedGerobakId == null) return '-';

    final found = gerobakOptions.where(
      (item) => item['id']?.toString() == selectedGerobakId,
    );

    if (found.isEmpty) return '-';
    return found.first['nama_gerobak']?.toString() ?? '-';
  }

  Map<String, dynamic> _resolveSelectedGerobak(
    List<Map<String, dynamic>> gerobaks,
  ) {
    final savedId = SelectedGerobakStore.selectedGerobakId;

    if (savedId != null) {
      for (final item in gerobaks) {
        if (item['id']?.toString() == savedId) {
          return item;
        }
      }
    }

    return gerobaks.first;
  }

  void _saveSelectedGerobakToStore(Map<String, dynamic> item) {
    SelectedGerobakStore.setGerobak(
      GerobakItem.fromMap(item),
    );
  }

  @override
  void initState() {
    super.initState();
    initDashboard();
  }

  Future<void> initDashboard() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      final role = await _stockService.getCurrentUserRole();
      final gerobaks = await _stockService.getGerobakOptionsByRole();

      if (gerobaks.isEmpty) {
        if (!mounted) return;
        setState(() {
          _role = role;
          gerobakOptions = [];
          selectedGerobakId = null;
          isLoading = false;
          errorMessage = 'Data gerobak kosong';
        });
        return;
      }

      final selectedGerobak = _resolveSelectedGerobak(gerobaks);
      final resolvedId = selectedGerobak['id']?.toString();

      _saveSelectedGerobakToStore(selectedGerobak);

      if (!mounted) return;
      setState(() {
        _role = role;
        gerobakOptions = gerobaks;
        selectedGerobakId = resolvedId;
      });

      await loadDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load data: $e';
      });
    }
  }

  Future<void> loadDashboard() async {
    if (selectedGerobakId == null) return;

    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      final revenue = await _reportService.getTotalRevenue(
        gerobakId: selectedGerobakId,
      );

      final orders = await _reportService.getTotalOrders(
        gerobakId: selectedGerobakId,
      );

      final topItems = await _reportService.getTopSellingItems(
        gerobakId: selectedGerobakId,
      );

      final recent = await _reportService.getRecentSales(
        gerobakId: selectedGerobakId,
      );

      final lowStock = await _loadLowStockCount();

      if (!mounted) return;
      setState(() {
        totalRevenue = revenue;
        totalOrders = orders;
        topSellingItems = topItems;
        recentSales = recent;
        lowStockCount = lowStock;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load dashboard: $e';
      });
    }
  }

  Future<int> _loadLowStockCount() async {
    if (selectedGerobakId == null) return 0;

    final result = await supabase
        .from('stok_gerobak')
        .select('stok_saat_ini')
        .eq('gerobak_id', selectedGerobakId!);

    int count = 0;

    for (final item in result) {
      final stock = ((item['stok_saat_ini'] ?? 0) as num).toInt();
      if (stock < 5) {
        count++;
      }
    }

    return count;
  }

  Future<void> _openSalesScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalesScreen()),
    );

    await loadDashboard();
  }

  Future<void> _openReportsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsScreen()),
    );

    await loadDashboard();
  }

  String _getTodayText() {
    final now = DateTime.now();

    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return "${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}";
  }

  String formatRupiah(int value) {
    return CurrencyFormatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: initDashboard,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            AppHeader(
              subtitle: _getTodayText(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _isRider
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedGerobakName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      )
                    : DropdownButton<String>(
                        isExpanded: true,
                        underline: const SizedBox(),
                        value: gerobakOptions.any(
                          (item) => item['id']?.toString() == selectedGerobakId,
                        )
                            ? selectedGerobakId
                            : null,
                        items: gerobakOptions.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['id']?.toString(),
                            child: Text(
                              item['nama_gerobak']?.toString() ?? '-',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;

                          final selected = gerobakOptions.firstWhere(
                            (item) => item['id']?.toString() == value,
                          );

                          if (!mounted) return;
                          setState(() => selectedGerobakId = value);

                          _saveSelectedGerobakToStore(selected);

                          await loadDashboard();
                        },
                      ),
              ),
            ),
            if (lowStockCount > 0)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "$lowStockCount item stock hampir habis",
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _openSalesScreen,
                            child: _miniStat(
                              "Sales",
                              formatRupiah(totalRevenue),
                              Icons.payments,
                              Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openReportsScreen,
                            child: _miniStat(
                              "Orders",
                              "$totalOrders",
                              Icons.receipt_long,
                              Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    "Top Selling Items",
                    topSellingItems.isEmpty
                        ? const EmptyState(
                            icon: Icons.local_cafe_outlined,
                            title: "Belum ada data penjualan",
                            subtitle:
                                "Data top selling item akan muncul setelah transaksi masuk.",
                          )
                        : Column(
                            children: topSellingItems
                                .take(5)
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                              final index = entry.key;
                              final item = entry.value;

                              final itemName = item['name']?.toString() ?? '-';
                              final qty = ((item['qty'] ?? 0) as num).toInt();
                              final revenue =
                                  ((item['revenue'] ?? 0) as num).toInt();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${index + 1}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "$qty sold",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formatRupiah(revenue),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    "Recent Sales",
                    recentSales.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: "Belum ada transaksi terbaru",
                            subtitle:
                                "Riwayat transaksi akan tampil di sini setelah ada penjualan.",
                          )
                        : Column(
                            children: recentSales.take(6).map((sale) {
                              final menuName =
                                  sale['menu_name']?.toString() ?? '-';
                              final qty = ((sale['qty'] ?? 0) as num).toInt();
                              final total =
                                  ((sale['total_harga'] ?? 0) as num).toInt();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withAlpha(16),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            menuName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "$qty item",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatRupiah(total),
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String title, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.black),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}