import 'package:flutter/material.dart';
import '../../core/app_constans.dart';
import '../../data/models/detail_transaksi_model.dart';
import '../../data/models/transaksi_model.dart';
import '../../data/services/stock_service.dart';
import '../../data/services/transaksi_service.dart';
import '../../utils/currency_formatter.dart';
import '../widgets/app_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/header.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final StockService _stockService = StockService();
  final TransaksiService _transaksiService = TransaksiService();

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> gerobakOptions = [];

  Map<String, dynamic>? selectedItem;
  String? selectedGerobakId;

  bool isLoading = true;
  bool isSaving = false;
  int qty = 1;
  String? payment;

  @override
  void initState() {
    super.initState();
    initSales();
  }

  Future<void> initSales() async {
    try {
      setState(() => isLoading = true);

      await _stockService.initializeStocksForAllGerobak(defaultStock: 20);
      final gerobaks = await _stockService.getGerobakOptions();

      if (gerobaks.isEmpty) {
        setState(() {
          gerobakOptions = [];
          selectedGerobakId = null;
          items = [];
          isLoading = false;
        });
        return;
      }

      selectedGerobakId ??= gerobaks.first['id']?.toString();

      setState(() {
        gerobakOptions = gerobaks;
      });

      await loadMenusByGerobak();
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load sales: $e")),
      );
    }
  }

  Future<void> loadMenusByGerobak() async {
    if (selectedGerobakId == null) {
      setState(() {
        items = [];
        isLoading = false;
      });
      return;
    }

    try {
      setState(() => isLoading = true);

      final data = await _stockService.getStocksByGerobak(selectedGerobakId!);

      setState(() {
        items = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load menu: $e")),
      );
    }
  }

  Future<void> _recordSale() async {
    if (selectedItem == null || payment == null || selectedGerobakId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih menu dan metode pembayaran dulu")),
      );
      return;
    }

    try {
      setState(() => isSaving = true);

      final menu = selectedItem!['menu'] as Map<String, dynamic>? ?? {};
      final String menuId = menu['id']?.toString() ?? '';
      final String menuName = menu['name']?.toString() ?? '-';
      final int price = ((menu['price'] ?? 0) as num).toInt();
      final int currentStock = ((selectedItem!['stock'] ?? 0) as num).toInt();

      if (menuId.isEmpty) {
        throw Exception('Menu tidak valid');
      }

      if (currentStock < qty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Stock $menuName tidak mencukupi")),
        );
        return;
      }

      final total = price * qty;

      final transaksiId = await _transaksiService.createTransaksi(
        TransaksiModel(
          totalHarga: total,
          gerobakId: selectedGerobakId!,
        ),
      );

      await _transaksiService.addDetail(
        DetailTransaksiModel(
          transaksiId: transaksiId,
          menuId: menuId,
          qty: qty,
          harga: price,
        ),
      );

      await _stockService.decreaseStock(
        menuId: menuId,
        gerobakId: selectedGerobakId!,
        qty: qty,
      );

      await loadMenusByGerobak();

      if (!mounted) return;
      _showSuccess();

      setState(() {
        selectedItem = null;
        payment = null;
        qty = 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan transaksi: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Berhasil"),
        content: const Text("Transaksi berhasil disimpan"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _formatRupiah(int value) {
    return CurrencyFormatter.format(value);
  }

  int get _selectedPrice {
    final menu = selectedItem?['menu'] as Map<String, dynamic>? ?? {};
    return ((menu['price'] ?? 0) as num).toInt();
  }

  String get _selectedName {
    final menu = selectedItem?['menu'] as Map<String, dynamic>? ?? {};
    return menu['name']?.toString() ?? '-';
  }

  String get _selectedEmoji {
    final menu = selectedItem?['menu'] as Map<String, dynamic>? ?? {};
    return menu['emoji']?.toString() ?? '☕';
  }

  int get _selectedStock {
    return ((selectedItem?['stock'] ?? 0) as num).toInt();
  }

  int get _totalPrice {
    return _selectedPrice * qty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.pageBackground,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          AppHeader(
                            subtitle: "Quick and easy sales entry",
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSmall,
                                ),
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
                                    selectedItem = null;
                                    qty = 1;
                                    payment = null;
                                  });

                                  await loadMenusByGerobak();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: items.isEmpty
                                ? const EmptyState(
                                    icon: Icons.inventory_2_outlined,
                                    title: "Menu belum tersedia",
                                    subtitle:
                                        "Belum ada item yang bisa dijual untuk gerobak ini.",
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.45,
                                    ),
                                    itemBuilder: (_, i) {
                                      final item = items[i];
                                      final menu = item['menu']
                                              as Map<String, dynamic>? ??
                                          {};

                                      final String menuId =
                                          menu['id']?.toString() ?? '';
                                      final String name =
                                          menu['name']?.toString() ?? '-';
                                      final String emoji =
                                          menu['emoji']?.toString() ?? '☕';
                                      final int price =
                                          ((menu['price'] ?? 0) as num).toInt();
                                      final int stock =
                                          ((item['stock'] ?? 0) as num).toInt();

                                      final isSelected =
                                          selectedItem?['menu_id'] == menuId;
                                      final isOutOfStock = stock <= 0;
                                      final isLowStock = stock > 0 &&
                                          stock < AppConstants.lowStockThreshold;

                                      return GestureDetector(
                                        onTap: isOutOfStock
                                            ? null
                                            : () {
                                                setState(() {
                                                  selectedItem = item;
                                                  qty = 1;
                                                  payment = null;
                                                });
                                              },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              AppConstants.radiusLarge,
                                            ),
                                            border: isSelected
                                                ? Border.all(
                                                    color: AppConstants
                                                        .primaryColor,
                                                    width: 1.8,
                                                  )
                                                : Border.all(
                                                    color:
                                                        Colors.grey.shade200,
                                                    width: 1,
                                                  ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isSelected
                                                    ? AppConstants.primaryColor
                                                        .withAlpha(35)
                                                    : Colors.black.withAlpha(10),
                                                blurRadius: isSelected ? 12 : 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                emoji.isEmpty ? "☕" : emoji,
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatRupiah(price),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isOutOfStock ||
                                                          isLowStock
                                                      ? Colors.red.withAlpha(18)
                                                      : Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                ),
                                                child: Text(
                                                  isOutOfStock
                                                      ? "Out of stock"
                                                      : "Stock $stock",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isOutOfStock ||
                                                            isLowStock
                                                        ? Colors.red
                                                        : Colors
                                                            .grey.shade700,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                  if (selectedItem != null) _buildBottomCheckout(),
                ],
              ),
            ),
    );
  }

  Widget _buildBottomCheckout() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withAlpha(16),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusSmall,
                    ),
                  ),
                  child: Text(
                    _selectedEmoji.isEmpty ? "☕" : _selectedEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Stock tersedia: $_selectedStock",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatRupiah(_selectedPrice),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildSmallSection(
                    title: "Qty",
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _qtyButton(
                          icon: Icons.remove,
                          onTap: qty > 1
                              ? () => setState(() => qty--)
                              : null,
                        ),
                        Text(
                          "$qty",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        _qtyButton(
                          icon: Icons.add,
                          onTap: qty < _selectedStock
                              ? () => setState(() => qty++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSmallSection(
                    title: "Payment",
                    child: Row(
                      children: [
                        Expanded(child: _paymentChip("Cash")),
                        const SizedBox(width: 8),
                        Expanded(child: _paymentChip("QRIS")),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withAlpha(12),
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusMedium,
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    "Total",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatRupiah(_totalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              text: "Save Transaction",
              onPressed: _recordSale,
              isLoading: isSaving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey : Colors.black87,
        ),
      ),
    );
  }

  Widget _paymentChip(String method) {
    final isSelected = payment == method;

    return GestureDetector(
      onTap: () => setState(() => payment = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          border: Border.all(
            color: isSelected
                ? AppConstants.primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            method,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}