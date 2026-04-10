import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/header.dart';
import '../widgets/dashboard_card.dart';
import '../../data/services/report_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ReportService _reportService = ReportService();
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  int totalRevenue = 0;
  int totalOrders = 0;
  List<Map<String, dynamic>> topSellingItems = [];
  List<Map<String, dynamic>> recentSales = [];

  String? selectedGerobakId;
  List<Map<String, dynamic>> gerobakOptions = [];

  @override
  void initState() {
    super.initState();
    initDashboard();
  }

  Future<void> initDashboard() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final data = await supabase
          .from('gerobak')
          .select('id, nama_gerobak')
          .order('nama_gerobak');

      gerobakOptions = List<Map<String, dynamic>>.from(data);

      if (gerobakOptions.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'Data gerobak kosong';
        });
        return;
      }

      selectedGerobakId = gerobakOptions.first['id']?.toString();

      await loadDashboard();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load gerobak: $e';
      });
    }
  }

  Future<void> loadDashboard() async {
    if (selectedGerobakId == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Gerobak belum dipilih';
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

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

      setState(() {
        totalRevenue = revenue;
        totalOrders = orders;
        topSellingItems = topItems;
        recentSales = recent;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load dashboard: $e';
      });
    }
  }

  String formatRupiah(int value) {
    return "Rp $value";
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
              ),
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

    return SingleChildScrollView(
      child: Column(
        children: [
          AppHeader(
            title: "AD.A Coffee",
            subtitle: _getTodayText(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                underline: const SizedBox(),
                value: selectedGerobakId,
                items: gerobakOptions.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['id']?.toString(),
                    child: Text(item['nama_gerobak']?.toString() ?? '-'),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;

                  setState(() {
                    selectedGerobakId = value;
                  });

                  await loadDashboard();
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              children: [
                SizedBox(
                  height: 75,
                  child: Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          icon: Icons.attach_money,
                          title: "Sales",
                          value: formatRupiah(totalRevenue),
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DashboardCard(
                          icon: Icons.receipt,
                          title: "Orders",
                          value: "$totalOrders",
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Best Selling Today",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (topSellingItems.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Belum ada data penjualan"),
                  )
                else
                  ...topSellingItems.take(4).map((item) {
                    return _buildBestItem(
                      item['name'] ?? '-',
                      "${item['qty'] ?? 0} sold",
                      formatRupiah((item['revenue'] ?? 0) as int),
                    );
                  }),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Recent Sales",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (recentSales.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Belum ada transaksi terbaru"),
                  )
                else
                  ...recentSales.take(4).map((item) {
                    return _buildRecentItem(
                      item['name'] ?? '-',
                      item['location'] ?? 'Unknown',
                      formatRupiah((item['price'] ?? 0) as int),
                      item['time'] ?? '-',
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestItem(String name, String sold, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_cafe, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  sold,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItem(
    String name,
    String location,
    String price,
    String time,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  location,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(color: Colors.orange),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}