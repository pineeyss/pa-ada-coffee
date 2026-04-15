import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/menu_item_model.dart';
import '../../data/services/menu_service.dart';
import '../widgets/header.dart';

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
      if (mounted) {
        setState(() => isLoading = true);
      }

      final data = await _menuService.getMenus();

      if (!mounted) return;
      setState(() {
        menuItems = data.take(12).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal load menu: $e')),
      );
    }
  }

  String _normalizeName(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }

  String? _getMenuImageAssetByName(String menuName) {
    final name = _normalizeName(menuName);

    const imageMap = <String, String>{
      'Americano'     : 'assets/images/menu_07.png',
      'Pandawa'       : 'assets/images/menu_06.png',
      'Butterscotch'  : 'assets/images/menu_06.png',
      'Caramel'       : 'assets/images/menu_06.png',
      'Hazelnut'      : 'assets/images/menu_06.png',
      'Salted Caramel': 'assets/images/menu_06.png',
      'Mico'          : 'assets/images/menu_06.png',
      'Lowco'         : 'assets/images/menu_03.png',
      'Matcha'        : 'assets/images/menu_05.png',
      'Taro'          : 'assets/images/menu_01.png',
      'Red Velvet'    : 'assets/images/menu_02.png',
      'Choco'         : 'assets/images/menu_04.png',
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
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: width,
            height: height,
            color: Colors.orange.withAlpha(18),
            alignment: Alignment.center,
            child: const Icon(
              Icons.local_cafe,
              size: 34,
              color: Colors.orange,
            ),
          );
        },
      ),
    );
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
    return AppHeader(
      title: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Menu Management",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Manage your coffee menu",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showAddModal,
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.add,
                color: Colors.orange,
                size: 28,
              ),
            ),
          ),
        ],
      ),
      subtitle: "${menuItems.length} items",
      child: TextField(
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
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (_, i) {
          final item = items[i];

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildMenuImage(
                          menuName: item.name,
                          index: i,
                          borderRadius: 18,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: PopupMenuButton<String>(
                          color: Colors.white,
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditModal(item, i);
                            } else if (value == 'delete') {
                              _deleteItem(item);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(110),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
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

    String category = "Coffee";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              final previewName =
                  name.text.trim().isEmpty ? "Menu Preview" : name.text.trim();
              final previewIndex = menuItems.length.clamp(0, 11);

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
                      Center(
                        child: _buildMenuImage(
                          menuName: previewName,
                          index: previewIndex,
                          width: 120,
                          height: 120,
                          borderRadius: 20,
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
                        onChanged: (_) => setStateModal(() {}),
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
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
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
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
                                      price: int.parse(price.text.trim()),
                                      category: category,
                                      stock: int.parse(stock.text.trim()),
                                      emoji: '☕',
                                    ),
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(sheetContext);
                                  await loadMenus();

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

  void _showEditModal(MenuItemModel item, int index) {
    final formKey = GlobalKey<FormState>();

    final name = TextEditingController(text: item.name);
    final price = TextEditingController(text: item.price.toString());
    final stock = TextEditingController(text: item.stock.toString());

    String category = item.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              final previewName =
                  name.text.trim().isEmpty ? item.name : name.text.trim();

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
                      Center(
                        child: _buildMenuImage(
                          menuName: previewName,
                          index: index,
                          width: 120,
                          height: 120,
                          borderRadius: 20,
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
                        onChanged: (_) => setStateModal(() {}),
                        decoration: _inputStyle("e.g. Americano"),
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
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
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
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
                                    item.id ?? '',
                                    MenuItemModel(
                                      id: item.id,
                                      name: name.text.trim(),
                                      price: int.parse(price.text.trim()),
                                      category: category,
                                      stock: int.parse(stock.text.trim()),
                                      emoji: item.emoji.isEmpty
                                          ? '☕'
                                          : item.emoji,
                                      createdAt: item.createdAt,
                                    ),
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(sheetContext);
                                  await loadMenus();

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
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Item"),
        content: Text("Are you sure you want to delete ${item.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _menuService.deleteMenu(item.id!);

                if (!mounted) return;
                Navigator.pop(dialogContext);
                await loadMenus();

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