import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/stock_service.dart';
import '../widgets/header.dart';
import '../../core/app_constans.dart';
import '../../utils/dialog_helper.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final supabase = Supabase.instance.client;
  final StockService _stockService = StockService();

  List<Map<String, dynamic>> data = [];
  List<Map<String, dynamic>> gerobak = [];

  String? selectedGerobak;

  String searchQuery = "";
  String selectedCategory = "All";
  bool isLoading = true;

  final categories = ["All", "Coffee", "Signature", "Premium", "Non Coffee"];

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
    init();
  }

  Future<void> init() async {
    try {
      setState(() => isLoading = true);

      final gerobakOptions = await _stockService.getGerobakOptionsByRole();
      
      if (gerobakOptions.isEmpty) {
        if (!mounted) return;
        setState(() {
          gerobak = [];
          selectedGerobak = null;
          data = [];
          isLoading = false;
        });
        return;
      }

      selectedGerobak ??= gerobakOptions.first['id']?.toString();

      if (!mounted) return;
      setState(() {
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
      setState(() => isLoading = true);

      final result = await _stockService.getStocksByGerobak(selectedGerobak!);

      if (!mounted) return;
      setState(() {
        data = result;
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
      // Hapus stok terkait dulu
      await supabase
          .from('stok_gerobak')
          .delete()
          .eq('menu_id', menu['id']);

      // Hapus detail transaksi kalau perlu
      await supabase
          .from('detail_transaksi')
          .delete()
          .eq('menu_id', menu['id']);

      // Hapus menu
      await supabase
          .from('menu')
          .delete()
          .eq('id', menu['id']);

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
        Text(label),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Add New Item",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                input("Item Name", name, hint: "e.g., Americano"),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Category"),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange),
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
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () async {
                          if (name.text.trim().isEmpty) {
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

                            final menuInsert = await supabase
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
                                .select()
                                .single();

                            final menuId = menuInsert['id'];

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
    );
  }

  void editModal(Map<String, dynamic> menu) {
    final name = TextEditingController(text: menu['name']?.toString() ?? '');
    final price = TextEditingController(
      text: (menu['price'] ?? 0).toString(),
    );
    final emoji = TextEditingController(
      text: (menu['emoji'] ?? '☕').toString(),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Edit Item",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                input("Item Name", name),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange),
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
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () async {
                          final ok = await DialogHelper.confirm(
                            context,
                            title: "Update Item",
                            message: "Simpan perubahan ini?",
                          );

                          if (!ok) return;

                          try {
                            await supabase
                                .from('menu')
                                .update({
                                  'name': name.text.trim(),
                                  'category': category,
                                  'price': int.tryParse(price.text.trim()) ?? 0,
                                  'emoji': emoji.text.trim().isEmpty
                                      ? '☕'
                                      : emoji.text.trim(),
                                })
                                .eq('id', menu['id']);

                            if (!mounted) return;
                            Navigator.pop(context);
                            await load();

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Menu berhasil diperbarui"),
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
    );
  }

  void updateStock(Map<String, dynamic> item) {
    final currentStock = ((item['stock'] ?? 0) as num).toInt();
    final stock = TextEditingController(text: currentStock.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Update Stock: ${item['menu']['name']}"),
              const SizedBox(height: 16),
              input(
                "New Stock Quantity",
                stock,
                hint: "Enter quantity",
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () async {
                        final ok = await DialogHelper.confirm(
                          context,
                          title: "Update Stock",
                          message: "Apakah jumlah stock sudah benar?",
                        );

                        if (!ok) return;

                        try {
                          await supabase
                              .from('stok_gerobak')
                              .update({
                                'stok_saat_ini':
                                    int.tryParse(stock.text.trim()) ?? 0,
                              })
                              .eq('id', item['id']);

                          if (!mounted) return;
                          Navigator.pop(context);
                          await load();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Stock berhasil diperbarui"),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Gagal update stock: $e"),
                            ),
                          );
                        }
                      },
                      child: const Text("Update Stock"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _stockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock < AppConstants.lowStockThreshold) return Colors.orange;
    return Colors.green;
  }

  String _stockLabel(int stock) {
    if (stock <= 0) return "Out of stock";
    return "$stock in stock";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.pageBackground,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppConstants.primaryColor,
        onPressed: addModal,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AppHeader(
                  subtitle: "Stock",
                  child: DropdownButton<String>(
                    value: selectedGerobak,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: gerobak
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['id']?.toString(),
                            child: Text(e['nama_gerobak']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() {
                        selectedGerobak = v;
                      });
                      await load();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: (v) => setState(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "Search menu items...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        final active = selectedCategory == cat;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: active,
                            selectedColor:
                                AppConstants.primaryColor.withAlpha(40),
                            onSelected: (_) {
                              setState(() => selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredData.isEmpty
                      ? const Center(
                          child: Text("Belum ada data stock"),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredData.length,
                          itemBuilder: (_, i) {
                            final item = filteredData[i];
                            final menu =
                                item['menu'] as Map<String, dynamic>? ?? {};
                            final stock = ((item['stock'] ?? 0) as num).toInt();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 6,
                                    color: Colors.black12,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    (menu['emoji'] ?? "☕").toString(),
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (menu['name'] ?? '-').toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          (menu['category'] ?? '-').toString(),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Rp ${menu['price'] ?? 0}",
                                          style: const TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _stockColor(stock)
                                                .withAlpha(40),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _stockLabel(stock),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.inventory_2,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () => updateStock(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => editModal(menu),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => deleteMenu(menu),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}