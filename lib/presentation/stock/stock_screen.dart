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

  List data = [];
  List gerobak = [];

  String? selectedGerobak;

  String searchQuery = "";
  String selectedCategory = "All";

  final categories = ["All", "Coffee", "Signature", "Premium", "Non Coffee"];

  List get filteredData {
    return data.where((item) {
      final menu = item['menu'];

      final name = (menu['name'] ?? "").toString().toLowerCase();
      final category = (menu['category'] ?? "").toString();

      final matchSearch = name.contains(searchQuery.toLowerCase());

      final matchCategory =
          selectedCategory == "All" || category.contains(selectedCategory);

      return matchSearch && matchCategory;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await _stockService.initializeStocksForAllGerobak(defaultStock: 20);

    gerobak = await _stockService.getGerobakOptions();
    selectedGerobak = gerobak.first['id'].toString();

    await load();
  }

  Future<void> load() async {
    data = await _stockService.getStocksByGerobak(selectedGerobak!);
    setState(() {});
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
      body: Column(
        children: [
          AppHeader(
            subtitle: "Stock",
            child: DropdownButton(
              value: selectedGerobak,
              isExpanded: true,
              underline: const SizedBox(),
              items: gerobak
                  .map((e) => DropdownMenuItem(
                        value: e['id'].toString(),
                        child: Text(e['nama_gerobak']),
                      ))
                  .toList(),
              onChanged: (v) async {
                selectedGerobak = v.toString();
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
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredData.length,
              itemBuilder: (_, i) {
                final item = filteredData[i];
                final menu = item['menu'];

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
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(menu['emoji'] ?? "☕",
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(menu['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(menu['category']),
                            const SizedBox(height: 4),
                            Text("Rp ${menu['price']}",
                                style:
                                    const TextStyle(color: Colors.orange)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text("${item['stock']} in stock",
                                  style:
                                      const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                          icon: const Icon(Icons.inventory_2,
                              color: Colors.orange),
                          onPressed: () => updateStock(item)),

                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => editModal(menu)),

                      IconButton(
  icon: const Icon(Icons.delete, color: Colors.red),
  onPressed: () async {
    if (!await DialogHelper.confirm(
      context,
      title: "Hapus Item",
      message: "Yakin ingin menghapus menu ini?",
    )) return;

    await supabase
        .from('menu')
        .delete()
        .eq('id', menu['id']);

    await load();
  },
),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget input(String label, TextEditingController c,
      {String hint = ""}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        )
      ],
    );
  }

  void addModal() {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    final emoji = TextEditingController(text: "☕");

    String category = "Coffee";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setModal) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("Add New Item",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 16),

              input("Item Name", name, hint: "e.g., Americano"),

              const SizedBox(height: 12),

              Align(
                  alignment: Alignment.centerLeft,
                  child: const Text("Category")),

              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton(
                  value: category,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                        value: "Coffee", child: Text("Coffee")),
                    DropdownMenuItem(
                        value: "Signature",
                        child: Text("Signature")),
                    DropdownMenuItem(
                        value: "Premium", child: Text("Premium")),
                    DropdownMenuItem(
                        value: "Non Coffee",
                        child: Text("Non Coffee")),
                  ],
                  onChanged: (v) => setModal(() => category = v!),
                ),
              ),

              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: input("Price (Rp)", price)),
                const SizedBox(width: 10),
                Expanded(child: input("Stock", stock)),
              ]),

              const SizedBox(height: 12),

              input("Emoji Icon", emoji),

              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"))),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        onPressed: () async {
                          if (!await DialogHelper.confirm(
                              context,
                              title: "Tambah Item",
                              message: "Apakah data sudah benar?",
                            )) return;

                          await supabase.from('menu').insert({
                            'name': name.text,
                            'category': category,
                            'price':
                                int.tryParse(price.text) ?? 0,
                            'emoji': emoji.text,
                          });

                          Navigator.pop(context);
                          await load();
                        },
                        child: const Text("Add Item")))
              ])
            ]),
          ),
        ),
      ),
    );
  }

  void editModal(Map menu) {
    final name = TextEditingController(text: menu['name']);
    final price =
        TextEditingController(text: menu['price'].toString());
    final emoji =
        TextEditingController(text: menu['emoji'] ?? "☕");

    String category = menu['category'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setModal) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("Edit Item",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 16),

              input("Item Name", name),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton(
                  value: category,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                        value: "Coffee", child: Text("Coffee")),
                    DropdownMenuItem(
                        value: "Signature",
                        child: Text("Signature")),
                    DropdownMenuItem(
                        value: "Premium", child: Text("Premium")),
                    DropdownMenuItem(
                        value: "Non Coffee",
                        child: Text("Non Coffee")),
                  ],
                  onChanged: (v) => setModal(() => category = v!),
                ),
              ),

              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: input("Price (Rp)", price)),
              ]),

              const SizedBox(height: 12),

              input("Emoji Icon", emoji),

              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"))),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        onPressed: () async {
                          if (!await DialogHelper.confirm(
                            context,
                            title: "Update Item",
                            message: "Simpan perubahan ini?",
                          )) return;

                          await supabase.from('menu').update({
                            'name': name.text,
                            'category': category,
                            'price':
                                int.tryParse(price.text) ?? 0,
                            'emoji': emoji.text,
                          }).eq('id', menu['id']);

                          Navigator.pop(context);
                          await load();
                        },
                        child:
                            const Text("Save Changes")))
              ])
            ]),
          ),
        ),
      ),
    );
  }

  void updateStock(Map item) {
    final stock = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Update Stock: ${item['menu']['name']}"),

            const SizedBox(height: 16),

            input("New Stock Quantity", stock,
                hint: "Enter quantity"),

            const SizedBox(height: 16),

            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"))),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      onPressed: () async {
                        if (!await DialogHelper.confirm(
                          context,
                          title: "Update Stock",
                          message: "Apakah jumlah stock sudah benar?",
                        )) return;

                        await supabase.from('stock_outlet').update({
                          'stock_outlet':
                              int.tryParse(stock.text) ?? 0,
                        }).eq('id', item['id']);

                        Navigator.pop(context);
                        await load();
                      },
                      child:
                          const Text("Update Stock")))
            ])
          ]),
        ),
      ),
    );
  }
}