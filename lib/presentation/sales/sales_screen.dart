import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/detail_transaksi_model.dart';
import '../../data/models/transaksi_model.dart';
import '../../data/services/stock_service.dart';
import '../../data/services/transaksi_service.dart';
import '../../data/services/report_service.dart';
import '../../data/services/google_sheet_service.dart';
import '../../utils/currency_formatter.dart';
import '../widgets/app_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/header.dart';
import '../../utils/dialog_helper.dart';
import '../../core/supabase/selected_gerobak_store.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final StockService _stockService = StockService();
  final TransaksiService _transaksiService = TransaksiService();
  final ReportService _reportService = ReportService();

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> gerobakOptions = [];

  Map<String, dynamic>? selectedItem;
  String? selectedGerobakId;
  String _role = 'owner';

  bool isLoading = true;
  bool isSaving = false;
  int qty = 1;
  String? payment;

  bool get _isRider => _role == 'rider';

  String get _selectedGerobakName {
    if (gerobakOptions.isEmpty || selectedGerobakId == null) return '-';

    final found = gerobakOptions.where(
      (item) => item['id']?.toString() == selectedGerobakId,
    );

    if (found.isEmpty) return '-';
    return found.first['nama_gerobak']?.toString() ?? '-';
  }

  String get todayText {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    return '$day/$month/$year';
  }

  void _handleSelectedGerobakChanged() {
    final newId = SelectedGerobakStore.selectedGerobakId;

    if (newId == null || newId == selectedGerobakId) return;
    if (!mounted) return;

    setState(() {
      selectedGerobakId = newId;
      selectedItem = null;
      qty = 1;
      payment = null;
    });

    loadMenusByGerobak();
  }

  @override
  void initState() {
    super.initState();

    SelectedGerobakStore.selectedGerobak.addListener(
      _handleSelectedGerobakChanged,
    );

    initSales();
  }

  @override
  void dispose() {
    SelectedGerobakStore.selectedGerobak.removeListener(
      _handleSelectedGerobakChanged,
    );
    super.dispose();
  }

  Future<void> initSales() async {
    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final role = await _stockService.getCurrentUserRole();
      final gerobaks = await _stockService.getGerobakOptionsByRole();

      if (gerobaks.isEmpty) {
        if (!mounted) return;
        setState(() {
          _role = role;
          gerobakOptions = [];
          selectedGerobakId = null;
          selectedItem = null;
          items = [];
          qty = 1;
          payment = null;
          isLoading = false;
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

      await loadMenusByGerobak();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load sales: $e")),
      );
    }
  }

  Future<void> loadMenusByGerobak() async {
    if (selectedGerobakId == null) {
      if (!mounted) return;
      setState(() {
        items = [];
        selectedItem = null;
        qty = 1;
        payment = null;
        isLoading = false;
      });
      return;
    }

    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final data = await _stockService.getStocksByGerobak(selectedGerobakId!);

      if (!mounted) return;
      setState(() {
        items = data.take(12).toList();
        isLoading = false;

        if (selectedItem != null) {
          final selectedMenuId = selectedItem!['menu_id']?.toString();
          final stillExists = items.any(
            (item) => item['menu_id']?.toString() == selectedMenuId,
          );

          if (!stillExists) {
            selectedItem = null;
            qty = 1;
            payment = null;
          } else {
            final freshSelected = items.firstWhere(
              (item) => item['menu_id']?.toString() == selectedMenuId,
            );
            selectedItem = freshSelected;

            final latestStock = ((freshSelected['stock'] ?? 0) as num).toInt();
            if (qty > latestStock) {
              qty = latestStock > 0 ? latestStock : 1;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load menu: $e")),
      );
    }
  }

  Future<bool> _syncTodayReportToSpreadsheet() async {
    if (selectedGerobakId == null) return false;

    try {
      final revenue = await _reportService.getTotalRevenue(
        gerobakId: selectedGerobakId,
      );

      final orders = await _reportService.getTotalOrders(
        gerobakId: selectedGerobakId,
      );

      final avg = orders > 0 ? (revenue / orders).round() : 0;

      final success = await GoogleSheetService.sendReport(
        tanggal: todayText,
        gerobakId: selectedGerobakId!,
        gerobakName: _selectedGerobakName,
        name: _selectedGerobakName,
        email: 'owner@email.com',
        role: _role,
        totalRevenue: revenue,
        totalOrders: orders,
        averageOrderValue: avg,
      );

      if (!success && kDebugMode) {
        debugPrint('Spreadsheet sync gagal');
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Spreadsheet sync error: $e');
      }
      return false;
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
      final ok = await DialogHelper.confirm(
        context,
        title: "Simpan Transaksi",
        message: "Apakah data sudah benar?",
      );

      if (!ok) return;

      if (mounted) {
        setState(() => isSaving = true);
      }

      final menu = selectedItem!['menu'] as Map<String, dynamic>? ?? {};
      final String menuId = menu['id']?.toString() ?? '';
      final String menuName = menu['name']?.toString() ?? '-';
      final int price = ((menu['price'] ?? 0) as num).toInt();
      final int currentStock = ((selectedItem!['stock'] ?? 0) as num).toInt();

      if (menuId.isEmpty) {
        throw Exception('Menu tidak valid');
      }

      if (qty <= 0) {
        throw Exception('Qty tidak valid');
      }

      if (currentStock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Stock $menuName sudah habis")),
        );
        return;
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

      await _syncTodayReportToSpreadsheet();
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

  int get _selectedStock {
    return ((selectedItem?['stock'] ?? 0) as num).toInt();
  }

  int get _totalPrice {
    return _selectedPrice * qty;
  }

  String _normalizeName(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }

  String? _getMenuImageAssetByName(String menuName) {
    final name = _normalizeName(menuName);

    const imageMap = <String, String>{
      'americano': 'assets/images/menu_07.png',
      'pandawa': 'assets/images/menu_06.png',
      'butterscotch': 'assets/images/menu_06.png',
      'caramel': 'assets/images/menu_06.png',
      'hazelnut': 'assets/images/menu_06.png',
      'salted caramel': 'assets/images/menu_06.png',
      'mico': 'assets/images/menu_06.png',
      'lowco': 'assets/images/menu_03.png',
      'matcha': 'assets/images/menu_05.png',
      'taro': 'assets/images/menu_01.png',
      'red velvet': 'assets/images/menu_02.png',
      'choco': 'assets/images/menu_04.png',
    };

    return imageMap[name];
  }

  String _getFallbackImageByIndex(int index) {
    const fallbackImages = [
      'assets/images/menu_01.png',
      'assets/images/menu_02.png',
      'assets/images/menu_03.png',
      'assets/images/menu_04.png',
      'assets/images/menu_05.png',
      'assets/images/menu_06.png',
      'assets/images/menu_07.png',
    ];

    if (index < 0 || index >= fallbackImages.length) {
      return fallbackImages.first;
    }

    return fallbackImages[index];
  }

  Widget _buildMenuImage({
    required String menuName,
    required int index,
    double? width,
    double? height,
    double borderRadius = 16,
  }) {
    final assetPath =
        _getMenuImageAssetByName(menuName) ?? _getFallbackImageByIndex(index);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Container(
            width: width,
            height: height,
            color: Colors.black.withAlpha(18),
            alignment: Alignment.center,
            child: const Icon(
              Icons.local_cafe,
              size: 34,
              color: Colors.black,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard({
    required Map<String, dynamic> item,
    required int index,
  }) {
    final menu = item['menu'] as Map<String, dynamic>? ?? {};

    final String menuId = menu['id']?.toString() ?? '';
    final String name = menu['name']?.toString() ?? '-';
    final int price = ((menu['price'] ?? 0) as num).toInt();
    final int stock = ((item['stock'] ?? 0) as num).toInt();

    final isSelected = selectedItem?['menu_id'] == menuId;
    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock < 5;

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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: Colors.black,
                  width: 1.8,
                )
              : Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.black.withAlpha(28)
                  : Colors.black.withAlpha(8),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isOutOfStock || isLowStock
                      ? Colors.red
                      : Colors.black87,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOutOfStock ? "Habis" : "Stok $stock",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: Center(
                child: _buildMenuImage(
                  menuName: name,
                  index: index,
                  width: 92,
                  height: 92,
                  borderRadius: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
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
                                      childAspectRatio: 0.92,
                                    ),
                                    itemBuilder: (_, i) {
                                      return _buildMenuCard(
                                        item: items[i],
                                        index: i,
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
    final selectedIndex = items.indexWhere(
      (item) =>
          item['menu_id']?.toString() == selectedItem?['menu_id']?.toString(),
    );

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
                _buildMenuImage(
                  menuName: _selectedName,
                  index: selectedIndex < 0 ? 0 : selectedIndex,
                  width: 56,
                  height: 56,
                  borderRadius: 14,
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
                    color: Colors.black,
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
                          onTap: qty > 1 ? () => setState(() => qty--) : null,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(12),
                borderRadius: BorderRadius.circular(16),
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
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              text: "Save Transaction",
              onPressed: isSaving ? null : _recordSale,
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
        borderRadius: BorderRadius.circular(16),
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
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
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