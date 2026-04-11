import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_constans.dart';
import '../../data/services/stock_service.dart';
import '../widgets/header.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final StockService _stockService = StockService();

  List<Map<String, dynamic>> stockItems = [];
  List<Map<String, dynamic>> gerobakOptions = [];

  bool isLoading = true;
  String? selectedGerobakId;
  bool _lowStockPopupShown = false;

  @override
  void initState() {
    super.initState();
    initStockPage();
  }

  Future<void> initStockPage() async {
    setState(() => isLoading = true);

    try {
      await _stockService.initializeStocksForAllGerobak(defaultStock: 20);

      final gerobaks = await _stockService.getGerobakOptions();

      if (gerobaks.isEmpty) {
        setState(() {
          gerobakOptions = [];
          selectedGerobakId = null;
          stockItems = [];
          isLoading = false;
        });
        return;
      }

      selectedGerobakId ??= gerobaks.first['id']?.toString();

      setState(() {
        gerobakOptions = gerobaks;
      });

      await loadStocks(showLowStockPopup: true);
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal inisialisasi stock: $e")),
      );
    }
  }

  Future<void> loadStocks({bool showLowStockPopup = false}) async {
    if (selectedGerobakId == null) {
      setState(() {
        stockItems = [];
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final data = await _stockService.getStocksByGerobak(selectedGerobakId!);

      setState(() {
        stockItems = data;
        isLoading = false;
      });

      if (showLowStockPopup) {
        _showLowStockWarningIfNeeded();
      }
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load stock: $e")),
      );
    }
  }

  void _showLowStockWarningIfNeeded() {
    if (!mounted) return;

    final lowStockItems = stockItems.where((item) {
      final stock = (item['stock'] ?? 0) as int;
      return stock < AppConstants.lowStockThreshold;
    }).toList();

    if (lowStockItems.isEmpty) return;
    if (_lowStockPopupShown) return;

    _lowStockPopupShown = true;

    final firstNames = lowStockItems.take(2).map((item) {
      final menu = item['menu'] as Map<String, dynamic>? ?? {};
      return menu['name']?.toString() ?? '-';
    }).join(', ');

    final extraCount = lowStockItems.length - 2;

    final message = extraCount > 0
        ? "Warning: stock menipis untuk $firstNames dan $extraCount item lainnya"
        : "Warning: stock menipis untuk $firstNames";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          ),
        );
    });
  }

  Future<void> updateStock({
    required String menuId,
    required int newStock,
  }) async {
    if (selectedGerobakId == null) return;

    try {
      await _stockService.updateStock(
        menuId: menuId,
        gerobakId: selectedGerobakId!,
        stock: newStock,
      );

      _lowStockPopupShown = false;
      await loadStocks(showLowStockPopup: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Stock berhasil diupdate"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal update stock: $e")),
      );
    }
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
    final lowStockCount = stockItems.where((item) {
      return ((item['stock'] ?? 0) as int) < AppConstants.lowStockThreshold;
    }).length;

    return Scaffold(
      backgroundColor: AppConstants.pageBackground,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AppHeader(
                  subtitle: todayText,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSmall),
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
                        _lowStockPopupShown = false;
                        await loadStocks(showLowStockPopup: true);
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
                        child: _buildMiniSummary(
                          icon: Icons.inventory_2_outlined,
                          title: "Total Items",
                          value: "${stockItems.length}",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMiniSummary(
                          icon: Icons.warning_amber_rounded,
                          title: "Low Stock",
                          value: "$lowStockCount",
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _lowStockPopupShown = false;
                      await loadStocks(showLowStockPopup: true);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: stockItems.length,
                      itemBuilder: (context, index) {
                        final item = stockItems[index];
                        final menu = item['menu'] as Map<String, dynamic>? ?? {};

                        final String menuId = menu['id']?.toString() ?? '';
                        final String name = menu['name']?.toString() ?? '-';
                        final String emoji = menu['emoji']?.toString() ?? '☕';
                        final int stock = (item['stock'] ?? 0) as int;
                        final bool isLow =
                            stock < AppConstants.lowStockThreshold;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppConstants.cardBackground,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor.withAlpha(18),
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSmall,
                                  ),
                                ),
                                child: Text(
                                  emoji.isEmpty ? "☕" : emoji,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLow
                                            ? Colors.red.withAlpha(18)
                                            : Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        "$stock units",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isLow
                                              ? Colors.red
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusSmall,
                                    ),
                                  ),
                                ),
                                onPressed: menuId.isEmpty
                                    ? null
                                    : () {
                                        _showUpdateDialog(
                                          context,
                                          menuId: menuId,
                                          menuName: name,
                                          currentStock: stock,
                                        );
                                      },
                                child: const Text("Update"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMiniSummary({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: AppConstants.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
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

  void _showUpdateDialog(
    BuildContext context, {
    required String menuId,
    required String menuName,
    required int currentStock,
  }) {
    final TextEditingController controller =
        TextEditingController(text: currentStock.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Update Stock: $menuName",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text("New Stock Quantity"),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: "Enter quantity",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusSmall),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSmall,
                          ),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = controller.text.trim();

                        if (text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Stock tidak boleh kosong"),
                            ),
                          );
                          return;
                        }

                        final newStock = int.tryParse(text);

                        if (newStock == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Stock harus berupa angka"),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);

                        await updateStock(
                          menuId: menuId,
                          newStock: newStock,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSmall,
                          ),
                        ),
                      ),
                      child: const Text("Update Stock"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}