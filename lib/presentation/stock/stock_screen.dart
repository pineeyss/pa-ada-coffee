import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/stock_service.dart';
import '../../data/services/menu_service.dart';
import '../widgets/header.dart';
import '../../utils/dialog_helper.dart';
import '../../core/supabase/selected_gerobak_store.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final StockService _stockService = StockService();
  final MenuService _menuService = MenuService();

  List<Map<String, dynamic>> data = [];
  List<Map<String, dynamic>> gerobak = [];

  String? selectedGerobak;
  String _role = 'owner';

  String searchQuery = "";
  String selectedCategory = "All";
  bool isLoading = true;

  final categories = ["All", "Coffee", "Signature", "Premium", "Non Coffee"];

  bool get _isRider => _role == 'rider';

  String get _selectedGerobakName {
    if (gerobak.isEmpty || selectedGerobak == null) return '-';

    final found = gerobak.where(
      (item) => item['id']?.toString() == selectedGerobak,
    );

    if (found.isEmpty) return '-';
    return found.first['nama_gerobak']?.toString() ?? '-';
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

  String _normalizeName(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }

  List<Map<String, dynamic>> _fallbackMasterMenus() {
    return [
      {'id': 'fallback_americano', 'name': 'Americano', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_pandawa', 'name': 'Pandawa', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_butterscotch', 'name': 'Butterscotch', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_caramel', 'name': 'Caramel', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_hazelnut', 'name': 'Hazelnut', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_salted_caramel', 'name': 'Salted Caramel', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_mico', 'name': 'Mico', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_lowco', 'name': 'Lowco', 'price': 13000, 'category': 'Coffee', 'emoji': '☕'},
      {'id': 'fallback_matcha', 'name': 'Matcha', 'price': 13000, 'category': 'Non Coffee', 'emoji': '🍵'},
      {'id': 'fallback_taro', 'name': 'Taro', 'price': 13000, 'category': 'Non Coffee', 'emoji': '🧋'},
      {'id': 'fallback_red_velvet', 'name': 'Red Velvet', 'price': 13000, 'category': 'Non Coffee', 'emoji': '🥤'},
      {'id': 'fallback_choco', 'name': 'Choco', 'price': 12000, 'category': 'Non Coffee', 'emoji': '🍫'},
    ];
  }

  void _handleSelectedGerobakChanged() {
    final newId = SelectedGerobakStore.selectedGerobakId;

    if (newId == null || newId == selectedGerobak) return;
    if (!mounted) return;

    setState(() {
      selectedGerobak = newId;
    });

    load();
  }

  List<Map<String, dynamic>> get filteredData {
    return data.where((item) {
      final menu = item['menu'] as Map<String, dynamic>? ?? {};

      final name = (menu['name'] ?? "").toString().toLowerCase();
      final category = (menu['category'] ?? "").toString();

      final matchSearch = name.contains(searchQuery.toLowerCase());
      final matchCategory =
          selectedCategory == "All" || category == selectedCategory;

      return matchSearch && matchCategory;
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    SelectedGerobakStore.selectedGerobak.addListener(
      _handleSelectedGerobakChanged,
    );

    init();
  }

  @override
  void dispose() {
    SelectedGerobakStore.selectedGerobak.removeListener(
      _handleSelectedGerobakChanged,
    );
    super.dispose();
  }

  Future<void> init() async {
    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final role = await _stockService.getCurrentUserRole();
      final gerobakOptions = await _stockService.getGerobakOptionsByRole();

      if (gerobakOptions.isEmpty) {
        if (!mounted) return;
        setState(() {
          _role = role;
          gerobak = [];
          selectedGerobak = null;
          data = [];
          isLoading = false;
        });
        return;
      }

      final storeId = SelectedGerobakStore.selectedGerobakId;

      final selected = gerobakOptions.any(
        (item) => item['id']?.toString() == storeId,
      )
          ? gerobakOptions.firstWhere(
              (item) => item['id']?.toString() == storeId,
            )
          : gerobakOptions.first;

      selectedGerobak = selected['id']?.toString();

      if (SelectedGerobakStore.selectedGerobak.value == null) {
        SelectedGerobakStore.setGerobak(
          GerobakItem.fromMap(selected),
        );
      }

      if (!mounted) return;
      setState(() {
        _role = role;
        gerobak = gerobakOptions;
      });

      await load();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal init stock: $e")),
      );
    }
  }

  Future<void> load() async {
    if (selectedGerobak == null) {
      if (!mounted) return;
      setState(() {
        data = [];
        isLoading = false;
      });
      return;
    }

    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final stockData = await _stockService.getStocksByGerobak(selectedGerobak!);

      List<dynamic> serviceMenus = [];
      try {
        serviceMenus = await _menuService.getMenus();
      } catch (_) {
        serviceMenus = [];
      }

      final fallbackMenus = _fallbackMasterMenus();

      final Map<String, Map<String, dynamic>> mergedMasterByName = {};

      for (final menu in fallbackMenus) {
        final normalized = _normalizeName(menu['name'].toString());
        mergedMasterByName[normalized] = {
          'id': menu['id'],
          'name': menu['name'],
          'price': menu['price'],
          'category': menu['category'],
          'emoji': menu['emoji'],
          'created_at': null,
        };
      }

      for (final menu in serviceMenus) {
        final name = (menu.name ?? '').toString();
        if (name.isEmpty) continue;

        final normalized = _normalizeName(name);
        mergedMasterByName[normalized] = {
          'id': menu.id,
          'name': menu.name,
          'price': menu.price ?? 0,
          'category': menu.category ?? 'Coffee',
          'emoji': menu.emoji,
          'created_at': menu.createdAt?.toIso8601String(),
        };
      }

      for (final stock in stockData) {
        final stockMenu = stock['menu'] as Map<String, dynamic>? ?? {};
        final stockMenuName = stockMenu['name']?.toString() ?? '';
        if (stockMenuName.isEmpty) continue;

        final normalized = _normalizeName(stockMenuName);

        mergedMasterByName.putIfAbsent(normalized, () {
          return {
            'id': stockMenu['id'],
            'name': stockMenu['name'],
            'price': stockMenu['price'] ?? 0,
            'category': stockMenu['category'] ?? 'Coffee',
            'emoji': stockMenu['emoji'],
            'created_at': stockMenu['created_at'],
          };
        });
      }

      final Map<String, Map<String, dynamic>> stockByName = {};
      for (final stock in stockData) {
        final stockMenu = stock['menu'] as Map<String, dynamic>? ?? {};
        final stockMenuName = stockMenu['name']?.toString() ?? '';
        if (stockMenuName.isEmpty) continue;

        stockByName[_normalizeName(stockMenuName)] = stock;
      }

      final List<Map<String, dynamic>> finalItems =
          mergedMasterByName.entries.map((entry) {
        final master = entry.value;
        final stockItem = stockByName[entry.key];
        final stockMenu = stockItem?['menu'] as Map<String, dynamic>? ?? {};

        final dynamic finalMenuId = stockMenu['id'] ?? master['id'];
        final int finalPrice =
            ((stockMenu['price'] ?? master['price'] ?? 0) as num).toInt();

        return {
          'id': stockItem?['id'],
          'gerobak_id': selectedGerobak,
          'menu_id': finalMenuId?.toString(),
          'stok_awal': stockItem?['stok_awal'] ?? 0,
          'stok_saat_ini': stockItem?['stok_saat_ini'] ?? 0,
          'created_at': stockItem?['created_at'],
          'stock': ((stockItem?['stok_saat_ini'] ?? 0) as num).toInt(),
          'menu': {
            'id': finalMenuId,
            'name': stockMenu['name'] ?? master['name'],
            'price': finalPrice,
            'category': stockMenu['category'] ?? master['category'],
            'emoji': stockMenu['emoji'] ?? master['emoji'],
            'created_at': stockMenu['created_at'] ?? master['created_at'],
          },
        };
      }).toList();

      finalItems.sort((a, b) {
        final nameA =
            ((a['menu'] as Map<String, dynamic>?)?['name'] ?? '').toString();
        final nameB =
            ((b['menu'] as Map<String, dynamic>?)?['name'] ?? '').toString();
        return nameA.compareTo(nameB);
      });

      if (!mounted) return;
      setState(() {
        data = finalItems;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load stock: $e")),
      );
    }
  }

  Future<void> deleteMenu(Map<String, dynamic> menu) async {
    final ok = await DialogHelper.confirm(
      context,
      title: "Hapus Item",
      message: "Yakin ingin menghapus menu ini?",
    );

    if (!ok) return;

    try {
      final menuId = menu['id']?.toString();
      if (menuId == null || menuId.isEmpty || menuId.startsWith('fallback_')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Menu ini belum tersimpan di database")),
        );
        return;
      }

      await supabase.from('stok_gerobak').delete().eq('menu_id', menuId);
      await supabase.from('detail_transaksi').delete().eq('menu_id', menuId);
      await supabase.from('menu').delete().eq('id', menuId);

      await load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Menu berhasil dihapus")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal hapus menu: $e")),
      );
    }
  }

  Widget input(
    String label,
    TextEditingController c, {
    String hint = "",
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  void addModal() {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController(text: "0");
    final emoji = TextEditingController(text: "☕");

    String category = "Coffee";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Add New Item",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  input("Item Name", name, hint: "e.g., Americano"),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Category",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: category,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: "Coffee",
                          child: Text("Coffee"),
                        ),
                        DropdownMenuItem(
                          value: "Signature",
                          child: Text("Signature"),
                        ),
                        DropdownMenuItem(
                          value: "Premium",
                          child: Text("Premium"),
                        ),
                        DropdownMenuItem(
                          value: "Non Coffee",
                          child: Text("Non Coffee"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() => category = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: input(
                          "Price (Rp)",
                          price,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: input(
                          "Stock",
                          stock,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  input("Emoji Icon", emoji),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (name.text.trim().isEmpty) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Nama menu wajib diisi"),
                                ),
                              );
                              return;
                            }

                            final ok = await DialogHelper.confirm(
                              context,
                              title: "Tambah Item",
                              message: "Apakah data sudah benar?",
                            );

                            if (!ok) return;

                            try {
                              final int parsedPrice =
                                  int.tryParse(price.text.trim()) ?? 0;
                              final int parsedStock =
                                  int.tryParse(stock.text.trim()) ?? 0;

                              final insertedMenu = await supabase
                                  .from('menu')
                                  .insert({
                                    'name': name.text.trim(),
                                    'category': category,
                                    'price': parsedPrice,
                                    'stock': parsedStock,
                                    'emoji': emoji.text.trim().isEmpty
                                        ? '☕'
                                        : emoji.text.trim(),
                                  })
                                  .select('id')
                                  .single();

                              final newMenuId = insertedMenu['id']?.toString();

                              if (newMenuId != null &&
                                  newMenuId.isNotEmpty &&
                                  selectedGerobak != null) {
                                await supabase.from('stok_gerobak').insert({
                                  'menu_id': newMenuId,
                                  'gerobak_id': selectedGerobak,
                                  'stok_awal': parsedStock,
                                  'stok_saat_ini': parsedStock,
                                });
                              }

                              if (!mounted) return;
                              Navigator.pop(context);
                              await load();

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Menu berhasil ditambahkan"),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Gagal tambah menu: $e"),
                                ),
                              );
                            }
                          },
                          child: const Text("Add Item"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void editModal(Map<String, dynamic> menu) {
    final menuId = menu['id']?.toString() ?? '';
    if (menuId.startsWith('fallback_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu ini belum tersimpan di database')),
      );
      return;
    }

    final name = TextEditingController(text: menu['name']?.toString() ?? '');
    final price = TextEditingController(
      text: (menu['price'] ?? 0).toString(),
    );

    String category = (menu['category'] ?? 'Coffee').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Edit Item",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  input("Item Name", name),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: category,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: "Coffee",
                          child: Text("Coffee"),
                        ),
                        DropdownMenuItem(
                          value: "Signature",
                          child: Text("Signature"),
                        ),
                        DropdownMenuItem(
                          value: "Premium",
                          child: Text("Premium"),
                        ),
                        DropdownMenuItem(
                          value: "Non Coffee",
                          child: Text("Non Coffee"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() => category = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  input(
                    "Price (Rp)",
                    price,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final ok = await DialogHelper.confirm(
                              context,
                              title: "Update Item",
                              message: "Simpan perubahan ini?",
                            );

                            if (!ok) return;

                            try {
                              await supabase.from('menu').update({
                                'name': name.text.trim(),
                                'category': category,
                                'price': int.tryParse(price.text.trim()) ?? 0,
                              }).eq('id', menu['id']);

                              if (!mounted) return;
                              Navigator.pop(context);
                              await load();

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Menu berhasil diupdate"),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Gagal update menu: $e"),
                                ),
                              );
                            }
                          },
                          child: const Text("Save Changes"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _stockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock < 5) return Colors.orange;
    return Colors.green;
  }

  String _stockLabel(int stock) {
    if (stock <= 0) return "Out of stock";
    return "$stock in stock";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: addModal,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                 AppHeader(
                  subtitle: todayText,
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
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            onChanged: (v) => setState(() => searchQuery = v),
                            decoration: const InputDecoration(
                              icon: Icon(Icons.search, color: Colors.black54),
                              hintText: "Search menu...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final c = categories[i];
                              final selected = c == selectedCategory;

                              return GestureDetector(
                                onTap: () => setState(() {
                                  selectedCategory = c;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.black
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? Colors.black
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    c,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (filteredData.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Center(
                              child: Text(
                                "Belum ada data stock",
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          )
                        else
                          ...filteredData.map((item) {
                            final menu =
                                item['menu'] as Map<String, dynamic>? ?? {};
                            final stock = ((item['stock'] ?? 0) as num).toInt();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(10),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(10),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          menu['name']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          menu['category']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Rp ${(menu['price'] ?? 0)}",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _stockColor(stock)
                                              .withAlpha(14),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _stockLabel(stock),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _stockColor(stock),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () => editModal(menu),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => deleteMenu(menu),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
