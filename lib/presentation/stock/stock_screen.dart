import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/stock_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final StockService _stockService = StockService();

  List<Map<String, dynamic>> stockItems = [];
  bool isLoading = true;

  String selectedGerobakId = 'owner';

  final List<Map<String, String>> gerobakOptions = const [
    {'id': 'owner', 'name': 'Rumah Owner'},
    {'id': 'gerobak_1', 'name': 'Gerobak 1'},
    {'id': 'gerobak_2', 'name': 'Gerobak 2'},
    {'id': 'gerobak_3', 'name': 'Gerobak 3'},
  ];

  @override
  void initState() {
    super.initState();
    loadStocks();
  }

  Future<void> loadStocks() async {
    setState(() => isLoading = true);

    try {
      final data = await _stockService.getStocksByGerobak(selectedGerobakId);

      setState(() {
        stockItems = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load stock: $e")),
      );
    }
  }

  Future<void> updateStock({
    required String menuId,
    required int newStock,
  }) async {
    try {
      await _stockService.updateStock(
        menuId: menuId,
        gerobakId: selectedGerobakId,
        stock: newStock,
      );

      await loadStocks();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Stock berhasil diupdate")),
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
    final lowStockCount =
        stockItems.where((item) => ((item['stock'] ?? 0) as int) < 5).length;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        "Stock Monitoring",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        todayText,
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
                          isExpanded: true,
                          underline: const SizedBox(),
                          value: selectedGerobakId,
                          items: gerobakOptions.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['id'],
                              child: Text(item['name']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedGerobakId = value;
                            });
                            loadStocks();
                          },
                        ),
                      ),
                    ],
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
                if (lowStockCount > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "$lowStockCount item stock kurang dari 5. Segera restock.",
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: loadStocks,
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
                        final bool isLow = stock < 5;

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
                              Text(
                                emoji.isEmpty ? "☕" : emoji,
                                style: const TextStyle(fontSize: 32),
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
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$stock units",
                                      style: TextStyle(
                                        color: isLow ? Colors.red : Colors.black87,
                                        fontWeight: isLow
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: Colors.orange),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
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
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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