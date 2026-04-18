import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/report_service.dart';
import '../../data/services/stock_service.dart';
import '../../utils/currency_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/header.dart';
import '../../core/supabase/selected_gerobak_store.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  final StockService _stockService = StockService();

  bool isLoading = true;
  String? errorMessage;

  int totalRevenue = 0;
  int totalOrders = 0;
  int averageOrderValue = 0;
  int weeklyRevenue = 0;
  int weeklyOrders = 0;

  List<Map<String, dynamic>> gerobakOptions = [];
  String? selectedGerobakId;
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

  void _handleSelectedGerobakChanged() {
    final newId = SelectedGerobakStore.selectedGerobakId;

    if (newId == null || newId == selectedGerobakId) return;
    if (!mounted) return;

    setState(() {
      selectedGerobakId = newId;
    });

    loadReports();
  }

  @override
  void initState() {
    super.initState();
    SelectedGerobakStore.selectedGerobak.addListener(
      _handleSelectedGerobakChanged,
    );
    initReports();
  }

  @override
  void dispose() {
    SelectedGerobakStore.selectedGerobak.removeListener(
      _handleSelectedGerobakChanged,
    );
    super.dispose();
  }

  Future<void> initReports() async {
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
          averageOrderValue = 0;
          weeklyRevenue = 0;
          weeklyOrders = 0;
          isLoading = false;
          errorMessage = 'Data gerobak kosong';
        });
        return;
      }

      final storeId = SelectedGerobakStore.selectedGerobakId;

      final selected = gerobaks.any(
        (item) => item['id']?.toString() == storeId,
      )
          ? gerobaks.firstWhere(
              (item) => item['id']?.toString() == storeId,
            )
          : gerobaks.first;

      selectedGerobakId = selected['id']?.toString();

      if (SelectedGerobakStore.selectedGerobak.value == null) {
        SelectedGerobakStore.setGerobak(
          GerobakItem.fromMap(selected),
        );
      }

      if (!mounted) return;
      setState(() {
        _role = role;
        gerobakOptions = gerobaks;
      });

      await loadReports();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load gerobak: $e';
      });
    }
  }

  Future<void> loadReports() async {
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

      if (!mounted) return;
      setState(() {
        totalRevenue = revenue;
        totalOrders = orders;
        weeklyRevenue = weeklyRev;
        weeklyOrders = weeklyOrd;
        averageOrderValue = orders > 0 ? (revenue / orders).round() : 0;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal load reports: $e';
      });
    }
  }

  Future<void> _openSpreadsheet() async {
    final url = _reportService.getSpreadsheetUrl(
      role: _role,
      gerobakName: _selectedGerobakName,
    );

    if (url == null || url.isEmpty || url.startsWith('ISI_LINK_')) {
      _showSnackBar('Link spreadsheet belum diisi');
      return;
    }

    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Gagal membuka spreadsheet');
    }
  }

  Future<void> _downloadReport() async {
    final url = _reportService.getDownloadUrl(
      role: _role,
      gerobakName: _selectedGerobakName,
    );

    if (url == null || url.isEmpty || url.startsWith('ISI_LINK_')) {
      _showSnackBar('Link download report belum diisi');
      return;
    }

    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Gagal membuka report');
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String formatRupiah(int value) {
    return CurrencyFormatter.format(value);
  }

  String get todayText {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : errorMessage != null
                ? RefreshIndicator(
                    onRefresh: initReports,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 120),
                        const Icon(
                          Icons.error_outline,
                          size: 56,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
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
                              child: SizedBox(
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    _selectedGerobakName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _buildSectionCard(
                              title: _isRider
                                  ? "Laporan ${_selectedGerobakName}"
                                  : "Laporan Keseluruhan",
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.table_chart_outlined,
                                      label: "Lihat Spreadsheet",
                                      onTap: _openSpreadsheet,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.download_outlined,
                                      label: "Download Report",
                                      onTap: _downloadReport,
                                    ),
                                  ),
                                ],
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
                                    iconBg: Colors.black.withAlpha(12),
                                    iconColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSummaryCard(
                                    icon: Icons.receipt_long_outlined,
                                    title: "Total Orders",
                                    value: "$totalOrders",
                                    iconBg: Colors.black.withAlpha(12),
                                    iconColor: Colors.black,
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
                              iconBg: Colors.black.withAlpha(12),
                              iconColor: Colors.black,
                              fullWidth: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _buildSectionCard(
                              title: "Daily Overview",
                              child: totalRevenue == 0 && totalOrders == 0
                                  ? const EmptyState(
                                      icon: Icons.insights_outlined,
                                      title: 'Belum ada data hari ini',
                                      subtitle:
                                          'Data revenue dan order harian akan muncul setelah ada transaksi.',
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _buildMiniStat(
                                            label: "Revenue",
                                            value: formatRupiah(totalRevenue),
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildMiniStat(
                                            label: "Orders",
                                            value: "$totalOrders",
                                            color: Colors.black,
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
                              child: weeklyRevenue == 0 && weeklyOrders == 0
                                  ? const EmptyState(
                                      icon: Icons.calendar_view_week_outlined,
                                      title: 'Belum ada data minggu ini',
                                      subtitle:
                                          'Data mingguan akan tampil kalau sudah ada transaksi minggu ini.',
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _buildMiniStat(
                                            label: "Revenue",
                                            value: formatRupiah(weeklyRevenue),
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildMiniStat(
                                            label: "Orders",
                                            value: "$weeklyOrders",
                                            color: Colors.black,
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
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Colors.black87,
          size: 20,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.black.withAlpha(28),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
          ),
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