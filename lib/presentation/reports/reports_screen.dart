import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/report_service.dart';
import '../../utils/currency_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/header.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  final SupabaseClient supabase = Supabase.instance.client;
  

  bool isLoading = true;
  String? errorMessage;

  int totalRevenue = 0;
  int totalOrders = 0;
  int averageOrderValue = 0;
  int weeklyRevenue = 0;
  int weeklyOrders = 0;


  List<Map<String, dynamic>> gerobakOptions = [];

  String? selectedGerobakId;

  @override
  void initState() {
    super.initState();
    initReports();
  }

  Future<void> initReports() async {
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

      await loadReports();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load gerobak: $e';
      });
    }
  }

  Future<void> loadReports() async {
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

      final weeklyRev = await _reportService.getWeeklyRevenue(
  gerobakId: selectedGerobakId,
);

final weeklyOrd = await _reportService.getWeeklyOrders(
  gerobakId: selectedGerobakId,
);

    setState(() {
      totalRevenue = revenue;
      totalOrders = orders;
      weeklyRevenue = weeklyRev;
      weeklyOrders = weeklyOrd;
      averageOrderValue = orders > 0 ? (revenue / orders).round() : 0;
      isLoading = false;
    });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load reports: $e';
      });
    }
  }

  String formatRupiah(int value) {
    return CurrencyFormatter.format(value);
  }

  String get todayText {
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

    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: initReports,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadReports,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        AppHeader(
                          subtitle: todayText,
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
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.payments_outlined,
                                  title: "Total Revenue",
                                  value: formatRupiah(totalRevenue),
                                  iconBg: Colors.orange.withAlpha(20),
                                  iconColor: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.receipt_long_outlined,
                                  title: "Total Orders",
                                  value: "$totalOrders",
                                  iconBg: Colors.amber.withAlpha(20),
                                  iconColor: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildSummaryCard(
                            icon: Icons.analytics_outlined,
                            title: "Avg Order Value",
                            value: formatRupiah(averageOrderValue),
                            iconBg: Colors.brown.withAlpha(18),
                            iconColor: Colors.brown,
                            fullWidth: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildSectionCard(
                            title: "Daily Overview",
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildMiniStat(
                                    label: "Revenue",
                                    value: formatRupiah(totalRevenue),
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMiniStat(
                                    label: "Orders",
                                    value: "$totalOrders",
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: _buildSectionCard(
    title: "Weekly Snapshot",
    child: Row(
      children: [
        Expanded(
          child: _buildMiniStat(
            label: "Revenue",
            value: formatRupiah(weeklyRevenue),
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStat(
            label: "Orders",
            value: "$weeklyOrders",
            color: Colors.amber.shade700,
          ),
        ),
      ],
    ),
  ),
),
const SizedBox(height: 20),                      
                        ],
                        ),
                        ),
                        ),
                            );
                          }
                          

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconBg,
    required Color iconColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
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

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}