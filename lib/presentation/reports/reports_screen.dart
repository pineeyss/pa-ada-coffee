import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  final SupabaseClient supabase = Supabase.instance.client;

  String selectedFilter = "Daily";
  final List<String> filters = ["Daily", "Weekly"];

  String? selectedGerobakId;
  List<Map<String, dynamic>> gerobakOptions = [];

  bool isLoading = true;
  int totalRevenue = 0;
  int totalOrders = 0;
  List<Map<String, dynamic>> topSellingItems = [];
  List<FlSpot> salesTrend = [];

  int get selectedDays => selectedFilter == "Daily" ? 1 : 7;

  @override
  void initState() {
    super.initState();
    initReports();
  }

  Future<void> initReports() async {
    try {
      setState(() => isLoading = true);

      final data = await supabase
          .from('gerobak')
          .select('id, nama_gerobak')
          .order('nama_gerobak');

      gerobakOptions = List<Map<String, dynamic>>.from(data);

      if (gerobakOptions.isNotEmpty) {
        selectedGerobakId = gerobakOptions.first['id']?.toString();
      }

      await loadReports();
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load gerobak: $e")),
      );
    }
  }

  Future<void> loadReports() async {
    if (selectedGerobakId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      setState(() => isLoading = true);

      final revenue = await _reportService.getTotalRevenue(
        gerobakId: selectedGerobakId,
        days: selectedDays,
      );

      final orders = await _reportService.getTotalOrders(
        gerobakId: selectedGerobakId,
        days: selectedDays,
      );

      final topItems = await _reportService.getTopSellingItems(
        gerobakId: selectedGerobakId,
        days: selectedDays,
      );

      final trend = await _reportService.getSalesTrend(
        gerobakId: selectedGerobakId,
        days: selectedDays,
      );

      setState(() {
        totalRevenue = revenue;
        totalOrders = orders;
        topSellingItems = topItems;
        salesTrend = trend;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load report: $e")),
      );
    }
  }

  String formatRupiah(int value) {
    return "Rp $value";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF7A1A), Color(0xFFFFA64D)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Reports & Analytics",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _reportService.getRangeLabel(selectedDays),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<String>(
                            value: selectedGerobakId,
                            isExpanded: true,
                            underline: const SizedBox(),
                            hint: const Text("Pilih Gerobak"),
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

                              setState(() {
                                selectedGerobakId = value;
                              });

                              await loadReports();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: filters.map((f) {
                      final isActive = selectedFilter == f;

                      return GestureDetector(
                        onTap: () async {
                          setState(() => selectedFilter = f);
                          await loadReports();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.orange : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildStatCard(
                          Icons.attach_money,
                          "Total Revenue",
                          formatRupiah(totalRevenue),
                        ),
                        _buildStatCard(
                          Icons.receipt,
                          "Total Orders",
                          "$totalOrders",
                        ),
                        _buildStatCard(
                          Icons.show_chart,
                          "Avg Order Value",
                          totalOrders == 0
                              ? "Rp 0"
                              : formatRupiah(totalRevenue ~/ totalOrders),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedFilter == "Daily"
                                ? "Sales Trend Today"
                                : "Sales Trend This Week",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: salesTrend.isEmpty
                                ? const Center(
                                    child: Text("Belum ada data grafik"),
                                  )
                                : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(show: true),
                                      borderData: FlBorderData(show: false),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 42,
                                            getTitlesWidget: (value, meta) {
                                              if (value == 0) {
                                                return const Text(
                                                  '0',
                                                  style: TextStyle(fontSize: 10),
                                                );
                                              }

                                              return Text(
                                                '${(value / 1000).toStringAsFixed(0)}k',
                                                style: const TextStyle(fontSize: 10),
                                              );
                                            },
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Text(
                                                  _reportService.getTrendBottomLabel(
                                                    value,
                                                    selectedDays,
                                                  ),
                                                  style: const TextStyle(fontSize: 10),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          isCurved: true,
                                          spots: salesTrend,
                                          dotData: FlDotData(show: true),
                                          barWidth: 3,
                                          belowBarData: BarAreaData(show: false),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedFilter == "Daily"
                              ? "Top Selling Items Today"
                              : "Top Selling Items This Week",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        if (topSellingItems.isEmpty)
                          const Text("Belum ada data penjualan")
                        else
                          ...topSellingItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;

                            final qty = (item['qty'] ?? 0) as int;
                            final revenue = (item['revenue'] ?? 0) as int;
                            final maxQty =
                                (topSellingItems.first['qty'] ?? 1) as int;
                            final progress = maxQty == 0
                                ? 0.0
                                : (qty / maxQty).clamp(0.0, 1.0);

                            return _buildTopItem(
                              "${index + 1}",
                              item['name'] ?? '-',
                              formatRupiah(revenue),
                              "$qty sold",
                              progress.toDouble(),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.withOpacity(0.2),
            child: Icon(icon, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItem(
    String rank,
    String name,
    String price,
    String soldText,
    double progress,
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
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.orange,
                child: Text(
                  rank,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                price,
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(width: 6),
              Text(
                soldText,
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}