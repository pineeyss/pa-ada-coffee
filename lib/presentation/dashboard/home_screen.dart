import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

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

  static bool _isMapRegistered = false;

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

  @override
  void initState() {
    super.initState();
    _registerGoogleMap();

    SelectedGerobakStore.selectedGerobak.addListener(
      _handleSelectedGerobakChanged,
    );
    SelectedGerobakStore.salesRefreshToken.addListener(_handleSalesChanged);

    initDashboard();
  }

  void _registerGoogleMap() {
    if (_isMapRegistered) return;
    _isMapRegistered = true;

    ui_web.platformViewRegistry.registerViewFactory(
      'google-map-gerobak',
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src =
              'https://maps.google.com/maps?width=600&height=400&hl=id&q=-0.02486,109.34067&z=16&ie=UTF8&t=&output=embed'
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;

        return iframe;
      },
    );
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

      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toIso8601String();

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
      final transaksiIds =
          transaksi.map((item) => item['id']).where((id) => id != null).toList();

      if (transaksiIds.isEmpty) return [];

      final details = await supabase
          .from('detail_transaksi')
          .select('qty, subtotal, menu_id, menu(name)')
          .inFilter('transaksi_id', transaksiIds);

      final Map<String, Map<String, dynamic>> grouped = {};

      for (final raw in details) {
        final item = Map<String, dynamic>.from(raw);
        final menu = item['menu'];
        final menuName =
            menu is Map<String, dynamic> ? menu['name']?.toString() ?? '-' : '-';

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
        final menuName =
            menu is Map<String, dynamic> ? menu['name']?.toString() ?? '-' : '-';

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
                            (item) =>
                                item['id']?.toString() == selectedGerobakId,
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

                    const SizedBox(height: 14),

                    _monitoringSensorSection(),
                  ],
                ),
              ),

              const SizedBox(height: 12),
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

  Widget _monitoringSensorSection() {
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
          const Text(
            "Monitoring Sensor Gerobak",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _locationSensorCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _batterySensorCard()),
              const SizedBox(width: 12),
              Expanded(child: _temperatureSensorCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationSensorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0F0F0)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _sensorIcon(
                icon: Icons.location_on,
                bgColor: const Color(0xFFEAF8EE),
                iconColor: Colors.green,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sensor Lokasi Gerobak",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Monitoring posisi gerobak berbasis GPS",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge("Aktif", Colors.green),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 180,
              color: Colors.grey.shade200,
              child: const HtmlElementView(
                viewType: 'google-map-gerobak',
              ),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _infoItem(
                  icon: Icons.place_outlined,
                  title: "Lokasi",
                  value: "Jl. Ahmad Yani, Pontianak",
                ),
              ),
              Expanded(
                child: _infoItem(
                  icon: Icons.gps_fixed,
                  title: "Koordinat",
                  value: "-0.02486, 109.34067",
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _infoItem(
                  icon: Icons.access_time,
                  title: "Update terakhir",
                  value: "18:05:02",
                ),
              ),
              Expanded(
                child: _infoItem(
                  icon: Icons.info_outline,
                  title: "Keterangan",
                  value: "Gerobak dapat dipantau posisinya secara real-time.",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _batterySensorCard() {
    return _smallSensorCard(
      icon: Icons.battery_charging_full,
      iconBg: const Color(0xFFEAF8EE),
      iconColor: Colors.green,
      title: "Sensor Baterai Gerobak",
      subtitle: "Monitoring daya baterai",
      badgeText: "Aman",
      badgeColor: Colors.green,
      leftLabel: "Persentase",
      leftValue: "78%",
      rightLabel: "Tegangan",
      rightValue: "12.4 V",
      progressValue: 0.78,
      progressColor: Colors.green,
      note: "Batas: Aman > 60% • Waspada 30-60% • Lemah < 30%",
    );
  }

  Widget _temperatureSensorCard() {
    return _smallSensorCard(
      icon: Icons.ac_unit,
      iconBg: const Color(0xFFEAF3FF),
      iconColor: Colors.blue,
      title: "Sensor Suhu Box Es",
      subtitle: "Monitoring suhu penyimpanan",
      badgeText: "Ideal",
      badgeColor: Colors.blue,
      leftLabel: "Suhu Saat Ini",
      leftValue: "4.2 °C",
      rightLabel: "Batas Ideal",
      rightValue: "0°C - 5°C",
      progressValue: 0.70,
      progressColor: Colors.blue,
      note: "Batas: Ideal 0-5°C • Mulai Naik 6-8°C • Bahaya > 8°C",
      leftValueColor: Colors.blue,
    );
  }

  Widget _smallSensorCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    required double progressValue,
    required Color progressColor,
    required String note,
    Color leftValueColor = Colors.black87,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0F0F0)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sensorIcon(
                icon: icon,
                bgColor: iconBg,
                iconColor: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(badgeText, badgeColor),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _sensorValue(
                  label: leftLabel,
                  value: leftValue,
                  valueColor: leftValueColor,
                ),
              ),
              Container(width: 1, height: 38, color: Colors.grey.shade200),
              const SizedBox(width: 10),
              Expanded(
                child: _sensorValue(
                  label: rightLabel,
                  value: rightValue,
                  valueColor: Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            note,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorIcon({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.black87),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sensorValue({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}