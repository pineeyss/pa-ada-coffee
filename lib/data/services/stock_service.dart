import 'package:supabase_flutter/supabase_flutter.dart';

class StockService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getGerobakOptions() async {
    final response = await supabase
        .from('gerobak')
        .select('id, nama_gerobak')
        .order('nama_gerobak');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> initializeStocksForAllGerobak({
    int defaultStock = 20,
  }) async {
    final menusResponse = await supabase.from('menu').select('id');
    final gerobakResponse = await supabase.from('gerobak').select('id');
    final existingResponse = await supabase
        .from('stock_outlet')
        .select('menu_id, gerobak_id');

    final menus = List<Map<String, dynamic>>.from(menusResponse);
    final gerobaks = List<Map<String, dynamic>>.from(gerobakResponse);
    final existing = List<Map<String, dynamic>>.from(existingResponse);

    final existingPairs = existing
        .map((e) => '${e['menu_id']}_${e['gerobak_id']}')
        .toSet();

    final List<Map<String, dynamic>> rowsToInsert = [];

    for (final menu in menus) {
      final menuId = menu['id']?.toString();
      if (menuId == null || menuId.isEmpty) continue;

      for (final gerobak in gerobaks) {
        final gerobakId = gerobak['id']?.toString();
        if (gerobakId == null || gerobakId.isEmpty) continue;

        final key = '${menuId}_$gerobakId';
        if (!existingPairs.contains(key)) {
          rowsToInsert.add({
            'menu_id': menuId,
            'gerobak_id': gerobakId,
            'stock': defaultStock,
          });
        }
      }
    }

    if (rowsToInsert.isNotEmpty) {
      await supabase.from('stock_outlet').insert(rowsToInsert);
    }
  }

  Future<List<Map<String, dynamic>>> getStocksByGerobak(String gerobakId) async {
    await initializeStocksForAllGerobak(defaultStock: 20);

    final response = await supabase
        .from('stock_outlet')
        .select(
          'id, stock, gerobak_id, menu_id, menu:menu_id(id, name, price, category, emoji, created_at)',
        )
        .eq('gerobak_id', gerobakId)
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> getStockByMenuAndGerobak({
    required String menuId,
    required String gerobakId,
  }) async {
    await createInitialStockIfNotExists(
      menuId: menuId,
      gerobakId: gerobakId,
      stock: 20,
    );

    final response = await supabase
        .from('stock_outlet')
        .select('stock')
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId)
        .maybeSingle();

    if (response == null) return 20;
    return (response['stock'] ?? 20) as int;
  }

  Future<void> updateStock({
    required String menuId,
    required String gerobakId,
    required int stock,
  }) async {
    final existing = await supabase
        .from('stock_outlet')
        .select('id')
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('stock_outlet').insert({
        'menu_id': menuId,
        'gerobak_id': gerobakId,
        'stock': stock,
      });
    } else {
      await supabase
          .from('stock_outlet')
          .update({
            'stock': stock,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('menu_id', menuId)
          .eq('gerobak_id', gerobakId);
    }
  }

  Future<void> decreaseStock({
    required String menuId,
    required String gerobakId,
    required int qty,
  }) async {
    final currentStock = await getStockByMenuAndGerobak(
      menuId: menuId,
      gerobakId: gerobakId,
    );

    final newStock = currentStock - qty;

    if (newStock < 0) {
      throw Exception('Stock tidak mencukupi');
    }

    await updateStock(
      menuId: menuId,
      gerobakId: gerobakId,
      stock: newStock,
    );
  }

  Future<void> createInitialStockIfNotExists({
    required String menuId,
    required String gerobakId,
    int stock = 20,
  }) async {
    final existing = await supabase
        .from('stock_outlet')
        .select('id')
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('stock_outlet').insert({
        'menu_id': menuId,
        'gerobak_id': gerobakId,
        'stock': stock,
      });
    }
  }
}