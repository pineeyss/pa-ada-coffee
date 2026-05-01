import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/currency_formatter.dart';
import '../../core/supabase/selected_gerobak_store.dart';
import '../widgets/header.dart';
import '../widgets/empty_state.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> gerobakOptions = [];
  bool isLoading = true;
  String? selectedGerobakId;

  @override
  void initState() {
    super.initState();
    _initializeData();
    SelectedGerobakStore.selectedGerobak.addListener(_handleSelectedGerobakChanged);
  }

  @override
  void dispose() {
    SelectedGerobakStore.selectedGerobak.removeListener(_handleSelectedGerobakChanged);
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final response = await supabase.from('gerobak').select('id, nama_gerobak');
      
      if (mounted) {
        setState(() {
          gerobakOptions = List<Map<String, dynamic>>.from(response);
          selectedGerobakId = SelectedGerobakStore.selectedGerobakId ?? 
                             (gerobakOptions.isNotEmpty ? gerobakOptions[0]['id'].toString() : null);
        });
        _loadMenuData();
      }
    } catch (e) {
      debugPrint("Error initializing data: $e");
    }
  }

  void _handleSelectedGerobakChanged() {
    if (!mounted) return;
    setState(() {
      selectedGerobakId = SelectedGerobakStore.selectedGerobakId;
    });
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    if (selectedGerobakId == null) return;
    try {
      if (mounted) setState(() => isLoading = true);
      
      // Mengambil stok dan data menu (termasuk image_url)
      final data = await supabase
          .from('stok_gerobak')
          .select('stok_saat_ini, menu(id, name, price, image_url)')
          .eq('gerobak_id', selectedGerobakId!);

      if (mounted) {
        setState(() {
          menuItems = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading sales: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          AppHeader(
            subtitle: formattedDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedGerobakId,
                  isExpanded: true,
                  hint: const Text("Pilih Gerobak"),
                  items: gerobakOptions.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['id'].toString(),
                      child: Text(
                        item['nama_gerobak'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final selected = gerobakOptions.firstWhere((g) => g['id'].toString() == value);
                      SelectedGerobakStore.setGerobak(GerobakItem.fromMap(selected));
                    }
                  },
                ),
              ),
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : menuItems.isEmpty
                    ? const EmptyState(
                        icon: Icons.coffee_outlined,
                        title: "Menu Kosong",
                        subtitle: "Belum ada menu untuk gerobak ini.",
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMenuData,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: menuItems.length,
                          itemBuilder: (context, index) {
                            final item = menuItems[index];
                            final menu = item['menu'];
                            final int stok = item['stok_saat_ini'] ?? 0;
                            return _buildMenuCard(menu, stok);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> menu, int stok) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Center(
                    child: (menu['image_url'] != null && menu['image_url'].toString().isNotEmpty)
                        ? Image.network(
                            menu['image_url'], 
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                          )
                        : const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu['name'] ?? 'Menu', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(menu['price'] ?? 0), 
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: stok <= 0 ? Colors.red : Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                stok <= 0 ? "Habis" : "Stok $stok", 
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
    );
  }
}