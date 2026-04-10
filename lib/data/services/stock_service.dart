import 'package:supabase_flutter/supabase_flutter.dart';

class StockService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getStocksByGerobak(String gerobakId) async {
    final response = await supabase
        .from('stock_outlet')
        .select('stock, gerobak_id, menu:menu_id(id, name, price, category, emoji, created_at)')
        .eq('gerobak_id', gerobakId)
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> getStockByMenuAndGerobak({
    required String menuId,
    required String gerobakId,
  }) async {
    final response = await supabase
        .from('stock_outlet')
        .select('stock')
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId)
        .maybeSingle();

    if (response == null) return 0;
    return (response['stock'] ?? 0) as int;
  }

  Future<void> updateStock({
    required String menuId,
    required String gerobakId,
    required int stock,
  }) async {
    await supabase
        .from('stock_outlet')
        .update({
          'stock': stock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId);
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
    int stock = 0,
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