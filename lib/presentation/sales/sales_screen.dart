import 'package:flutter/material.dart';
import '../../data/models/menu_item_model.dart';
import '../../data/models/transaksi_model.dart';
import '../../data/models/detail_transaksi_model.dart';
import '../../data/services/menu_service.dart';
import '../../data/services/transaksi_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final MenuService _menuService = MenuService();
  final TransaksiService _transaksiService = TransaksiService();

  List<MenuItemModel> items = [];
  MenuItemModel? selectedItem;

  bool isLoading = true;
  int qty = 1;
  String? payment;

  @override
  void initState() {
    super.initState();
    loadMenus();
  }

  Future<void> loadMenus() async {
    try {
      final data = await _menuService.getMenus();

      setState(() {
        items = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal load menu: $e")),
      );
    }
  }

  Future<void> _recordSale() async {
    if (selectedItem == null || payment == null) return;

    try {
      final item = selectedItem!;

      if (item.stock < qty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Stock tidak mencukupi"),
          ),
        );
        return;
      }

      final total = item.price * qty;

      final gerobakData = await Supabase.instance.client
    .from('gerobak')
    .select('id')
    .limit(1)
    .single();

      final transaksiId = await _transaksiService.createTransaksi(
        TransaksiModel(
          totalHarga: total,
          gerobakId: gerobakData['id'],
        ),
      );

      await _transaksiService.addDetail(
        DetailTransaksiModel(
          transaksiId: transaksiId,
          menuId: item.id!,
          qty: qty,
          harga: item.price,
        ),
      );

      final newStock = item.stock - qty;

      await _menuService.updateMenu(
        item.id!,
        MenuItemModel(
          id: item.id,
          name: item.name,
          price: item.price,
          category: item.category,
          stock: newStock,
          emoji: item.emoji,
          createdAt: item.createdAt,
        ),
      );

      await loadMenus();

      _showSuccess();

      setState(() {
        selectedItem = null;
        payment = null;
        qty = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan transaksi: $e")),
      );
    }
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
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF7A1A), Color(0xFFFFA64D)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Record Sale",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Quick and easy sales entry",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final isSelected = selectedItem?.id == item.id;
                        final isOutOfStock = item.stock <= 0;

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
                          child: Opacity(
                            opacity: isOutOfStock ? 0.5 : 1,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.orange,
                                        width: 2,
                                      )
                                    : null,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                  )
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.emoji.isEmpty ? "☕" : item.emoji,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Rp ${item.price}",
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOutOfStock
                                        ? "Out of Stock"
                                        : "Stock: ${item.stock}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOutOfStock
                                          ? Colors.red
                                          : Colors.grey,
                                      fontWeight: isOutOfStock
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (selectedItem != null) ...[
                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Quantity"),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (qty > 1) {
                                      setState(() => qty--);
                                    }
                                  },
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(
                                  "$qty",
                                  style: const TextStyle(fontSize: 18),
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (qty < selectedItem!.stock) {
                                      setState(() => qty++);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Payment Method"),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _paymentCard("Cash", Icons.money),
                              _paymentCard("Digital", Icons.phone_android,),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (payment != null) ...[
                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Total Amount"),
                                Text(
                                  "Rp ${selectedItem!.price * qty}",
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _recordSale,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text("Record Sale"),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _paymentCard(String title, IconData icon) {
    final active = payment == title;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => payment = title);
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: Colors.orange, width: 2)
                : null,
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6)
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: active ? Colors.orange : Colors.grey,
              ),
              const SizedBox(height: 6),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
              SizedBox(height: 10),
              Text(
                "Sale Recorded!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text("Successfully added to today's sales"),
            ],
          ),
        );
      },
    );
  }
}