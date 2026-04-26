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

  void _handleSelectedGerobakChanged() {
    final newId = SelectedGerobakStore.selectedGerobakId;
    if (newId == null || newId == selectedGerobakId) return;
    if (!mounted) return;

    setState(() {
      selectedGerobakId = newId;
    });

    loadDashboard();
  }

  void _handleSalesChanged() {
    if (!mounted || selectedGerobakId == null) return;
    loadDashboard();
  }

  @override
  void initState() {
    super.initState();
    SelectedGerobakStore.selectedGerobak.addListener(
      _handleSelectedGerobakChanged,
    );
    SelectedGerobakStore.salesRefreshToken.addListener(_handleSalesChanged);
    initDashboard();
  }

  @override
  void dispose() {
    SelectedGerobakStore.selectedGerobak.removeListener(
      _handleSelectedGerobakChanged,
    );
    SelectedGerobakStore.salesRefreshToken.removeListener(_handleSalesChanged);
    super.dispose();
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
          totalRevenue = 0;
          totalOrders = 0;
          topSellingItems = [];
          recentSales = [];
          lowStockCount = 0;
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
    if (selectedGerobakId == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Gerobak belum dipilih';
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      final transaksi = await supabase
          .from('transaksi')
          .select('id, total_harga, tanggal')
          .eq('gerobak_id', selectedGerobakId!)
          .order('tanggal', ascending: false);

      int revenue = 0;
      for (final item in transaksi) {
        revenue += ((item['total_harga'] ?? 0) as num).toInt();
      }

      final orders = transaksi.length;
      final topItems = await _getTopSellingItemsFromTransaksi(transaksi);
      final recent = await _getRecentSalesFromTransaksi(transaksi);
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

  Future<List<Map<String, dynamic>>> _getTopSellingItemsFromTransaksi(
    List<dynamic> transaksi,
  ) async {
    if (transaksi.isEmpty) return [];

    try {
      final transaksiIds = transaksi
          .map((item) => item['id'])
          .where((id) => id != null)
          .toList();

      if (transaksiIds.isEmpty) return [];

      final details = await supabase
          .from('detail_transaksi')
          .select('qty, subtotal, menu_id, menu(name)')
          .inFilter('transaksi_id', transaksiIds);

      final Map<String, Map<String, dynamic>> grouped = {};

      for (final raw in details) {
        final item = Map<String, dynamic>.from(raw);
        final menu = item['menu'];
        final menuName = menu is Map<String, dynamic>
            ? menu['name']?.toString() ?? '-'
            : '-';

        final qty = ((item['qty'] ?? 0) as num).toInt();
        final subtotal = ((item['subtotal'] ?? 0) as num).toInt();

        if (!grouped.containsKey(menuName)) {
          grouped[menuName] = {
            'name': menuName,
            'qty': 0,
            'revenue': 0,
          };
        }

        grouped[menuName]!['qty'] =
            ((grouped[menuName]!['qty'] ?? 0) as int) + qty;
        grouped[menuName]!['revenue'] =
            ((grouped[menuName]!['revenue'] ?? 0) as int) + subtotal;
      }

      final result = grouped.values.toList();
      result.sort(
        (a, b) => ((b['qty'] ?? 0) as int).compareTo((a['qty'] ?? 0) as int),
      );

      return result;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentSalesFromTransaksi(
    List<dynamic> transaksi,
  ) async {
    if (transaksi.isEmpty) return [];

    try {
      final latestTransaksi = transaksi.take(6).toList();

      final transaksiIds = latestTransaksi
          .map((item) => item['id'])
          .where((id) => id != null)
          .toList();

      if (transaksiIds.isEmpty) return [];

      final details = await supabase
          .from('detail_transaksi')
          .select('transaksi_id, qty, menu(name)')
          .inFilter('transaksi_id', transaksiIds);

      final Map<String, Map<String, dynamic>> detailByTransaksi = {};

      for (final raw in details) {
        final item = Map<String, dynamic>.from(raw);
        final transaksiId = item['transaksi_id']?.toString();
        if (transaksiId == null || detailByTransaksi.containsKey(transaksiId)) {
          continue;
        }

        final menu = item['menu'];
        final menuName = menu is Map<String, dynamic>
            ? menu['name']?.toString() ?? '-'
            : '-';

        detailByTransaksi[transaksiId] = {
          'menu_name': menuName,
          'qty': ((item['qty'] ?? 0) as num).toInt(),
        };
      }

      return latestTransaksi.map<Map<String, dynamic>>((raw) {
        final trx = Map<String, dynamic>.from(raw);
        final trxId = trx['id']?.toString() ?? '';
        final detail = detailByTransaksi[trxId] ?? {};

        return {
          'menu_name': detail['menu_name']?.toString() ?? '-',
          'qty': ((detail['qty'] ?? 0) as num).toInt(),
          'total_harga': ((trx['total_harga'] ?? 0) as num).toInt(),
        };
      }).toList();
    } catch (_) {
      return [];
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 12),
                Text(errorMessage!, textAlign: TextAlign.center),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: initDashboard,
                  child: Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              AppHeader(
                subtitle: _getTodayText(),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isRider
                      ? Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedGerobakName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: gerobakOptions.any(
                              (item) =>
                                  item['id']?.toString() == selectedGerobakId,
                            )
                                ? selectedGerobakId
                                : null,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            items: gerobakOptions.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['id']?.toString(),
                                child: Text(
                                  item['nama_gerobak']?.toString() ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              if (value == null) return;

                              final selected = gerobakOptions.firstWhere(
                                (item) => item['id']?.toString() == value,
                              );

                              setState(() => selectedGerobakId = value);

                              _saveSelectedGerobakToStore(selected);

                              await loadDashboard();
                            },
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    if (lowStockCount > 0) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_rounded,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "$lowStockCount item stock hampir habis",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                            child: _miniStat(
                              "Sales",
                              formatRupiah(totalRevenue),
                              Icons.payments,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniStat(
                              "Orders",
                              "$totalOrders",
                              Icons.receipt_long,
                              Colors.amber,
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

                                final itemName =
                                    item['name']?.toString() ?? '-';
                                final qty =
                                    ((item['qty'] ?? 0) as num).toInt();
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
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                                final qty =
                                    ((sale['qty'] ?? 0) as num).toInt();
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
                                          borderRadius:
                                              BorderRadius.circular(12),
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