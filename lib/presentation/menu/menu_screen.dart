import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/menu_item_model.dart';
import '../../data/services/menu_service.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final MenuService _menuService = MenuService();

  List<MenuItemModel> menuItems = [];
  bool isLoading = true;
  String selectedCategory = "All";
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadMenus();
  }

  Future<void> loadMenus() async {
    try {
      setState(() => isLoading = true);

      final data = await _menuService.getMenus();

      setState(() {
        menuItems = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal load menu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = menuItems.where((item) {
      final matchCategory =
          selectedCategory == "All" || item.category == selectedCategory;
      final matchSearch =
          item.name.toLowerCase().contains(searchQuery.toLowerCase());
      return matchCategory && matchSearch;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          _header(),
          _categoryFilter(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _menuList(filteredItems),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF7A1A), Color(0xFFFFA64D)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Menu Management",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${menuItems.length} items",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showAddModal,
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.add, color: Colors.orange),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: "Search menu items...",
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryFilter() {
    final cats = ["All", "Coffee", "Signature", "Premium", "Non Coffee"];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: cats.map((cat) {
          final active = selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? Colors.orange : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: active ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _menuList(List<MenuItemModel> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text("Belum ada menu"),
      );
    }

    return RefreshIndicator(
      onRefresh: loadMenus,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];

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
                  item.emoji.isEmpty ? "☕" : item.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Rp ${item.price}",
                        style: const TextStyle(color: Colors.orange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${item.category} • Stock ${item.stock}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEditModal(item),
                  child: const Icon(Icons.edit, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _deleteItem(item),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddModal() {
    final formKey = GlobalKey<FormState>();

    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    final emoji = TextEditingController();

    String category = "Coffee";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Add New Item",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Item Name",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: name,
                        decoration: _inputStyle("e.g., Americano"),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Nama menu wajib diisi';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        "Category",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
                            if (v != null) {
                              setStateModal(() => category = v);
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Price (Rp)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: price,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _inputStyle("0"),
                                  validator: (value) {
                                    final text = (value ?? '').trim();

                                    if (text.isEmpty) {
                                      return 'Harga wajib diisi';
                                    }

                                    final parsed = int.tryParse(text);
                                    if (parsed == null) {
                                      return 'Harga harus angka';
                                    }

                                    if (parsed < 0) {
                                      return 'Harga tidak boleh minus';
                                    }

                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Stock",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: stock,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _inputStyle("0"),
                                  validator: (value) {
                                    final text = (value ?? '').trim();

                                    if (text.isEmpty) {
                                      return 'Stock wajib diisi';
                                    }

                                    final parsed = int.tryParse(text);
                                    if (parsed == null) {
                                      return 'Stock harus angka';
                                    }

                                    if (parsed < 0) {
                                      return 'Stock tidak boleh minus';
                                    }

                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        "Emoji Icon",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emoji,
                        decoration: _inputStyle("☕"),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                                if (!formKey.currentState!.validate()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Mohon isi semua field dengan benar',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await _menuService.addMenu(
                                    MenuItemModel(
                                      name: name.text.trim(),
                                      price:
                                          int.parse(price.text.trim()),
                                      category: category,
                                      stock:
                                          int.parse(stock.text.trim()),
                                      emoji: emoji.text.trim(),
                                    ),
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  await loadMenus();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Menu berhasil ditambahkan"),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text("Gagal menambahkan menu: $e"),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Add Item"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showEditModal(MenuItemModel item) {
    final formKey = GlobalKey<FormState>();

    final name = TextEditingController(text: item.name);
    final price = TextEditingController(text: item.price.toString());
    final stock = TextEditingController(text: item.stock.toString());
    final emoji = TextEditingController(text: item.emoji);

    String category = item.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Edit Item",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Item Name",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: name,
                        decoration: _inputStyle("e.g., Americano"),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Nama menu wajib diisi';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        "Category",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
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
                            if (v != null) {
                              setStateModal(() => category = v);
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Price (Rp)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: price,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _inputStyle("0"),
                                  validator: (value) {
                                    final text = (value ?? '').trim();

                                    if (text.isEmpty) {
                                      return 'Harga wajib diisi';
                                    }

                                    final parsed = int.tryParse(text);
                                    if (parsed == null) {
                                      return 'Harga harus angka';
                                    }

                                    if (parsed < 0) {
                                      return 'Harga tidak boleh minus';
                                    }

                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Stock",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: stock,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _inputStyle("0"),
                                  validator: (value) {
                                    final text = (value ?? '').trim();

                                    if (text.isEmpty) {
                                      return 'Stock wajib diisi';
                                    }

                                    final parsed = int.tryParse(text);
                                    if (parsed == null) {
                                      return 'Stock harus angka';
                                    }

                                    if (parsed < 0) {
                                      return 'Stock tidak boleh minus';
                                    }

                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        "Emoji Icon",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emoji,
                        decoration: _inputStyle("☕"),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                                if (!formKey.currentState!.validate()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Mohon isi semua field dengan benar',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await _menuService.updateMenu(
                                    item.id!,
                                    MenuItemModel(
                                      id: item.id,
                                      name: name.text.trim(),
                                      price:
                                          int.parse(price.text.trim()),
                                      category: category,
                                      stock:
                                          int.parse(stock.text.trim()),
                                      emoji: emoji.text.trim(),
                                      createdAt: item.createdAt,
                                    ),
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  await loadMenus();

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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Save Changes"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _deleteItem(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Item"),
        content: Text("Are you sure you want to delete ${item.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _menuService.deleteMenu(item.id!);

                if (!mounted) return;
                Navigator.pop(context);
                await loadMenus();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Menu berhasil dihapus")),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Gagal hapus menu: $e")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          )
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}