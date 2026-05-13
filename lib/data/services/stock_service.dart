import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<String> getCurrentUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 'owner';

    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    return (profile?['role'] ?? 'owner').toString().toLowerCase();
  }

  Future<List<Map<String, dynamic>>> getGerobakOptions() async {
    final response = await supabase
        .from('gerobak')
        .select('id, nama_gerobak, rider_id')
        .order('nama_gerobak');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getGerobakOptionsByRole() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      final response = await supabase
          .from('gerobak')
          .select('id, nama_gerobak, rider_id')
          .order('nama_gerobak');

      return List<Map<String, dynamic>>.from(response);
    }

    final role = await getCurrentUserRole();

    if (role == 'rider') {
      final rider = await supabase
          .from('riders')
          .select('id')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (rider == null) {
        return [];
      }

      final riderId = rider['id']?.toString();
      if (riderId == null || riderId.isEmpty) {
        return [];
      }

      final response = await supabase
          .from('gerobak')
          .select('id, nama_gerobak, rider_id')
          .eq('rider_id', riderId)
          .order('nama_gerobak');

      return List<Map<String, dynamic>>.from(response);
    }

    final response = await supabase
        .from('gerobak')
        .select('id, nama_gerobak, rider_id')
        .order('nama_gerobak');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getStocksByGerobak(String gerobakId) async {
    final response = await supabase
        .from('stok_gerobak')
        .select('''
          id,
          gerobak_id,
          menu_id,
          stok_awal,
          stok_saat_ini,
          created_at,
          menu:menu_id (
            id,
            name,
            price,
            category,
            emoji,
            created_at
          )
        ''')
        .eq('gerobak_id', gerobakId)
        .order('created_at', ascending: false);

    final data = List<Map<String, dynamic>>.from(response);

    return data.map((item) {
      return {
        ...item,
        'stock': item['stok_saat_ini'] ?? 0,
      };
    }).toList();
  }

  Future<int> getStockByMenuAndGerobak({
    required String menuId,
    required String gerobakId,
  }) async {
    final response = await supabase
        .from('stok_gerobak')
        .select('stok_saat_ini')
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId)
        .maybeSingle();

    if (response == null) return 0;
    return ((response['stok_saat_ini'] ?? 0) as num).toInt();
  }

  Future<void> updateStock({
    required String menuId,
    required String gerobakId,
    required int stock,
  }) async {
    final existing = await supabase
        .from('stok_gerobak')
        .select('id')
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('stok_gerobak').insert({
        'menu_id': menuId,
        'gerobak_id': gerobakId,
        'stok_awal': stock,
        'stok_saat_ini': stock,
      });
    } else {
      await supabase
          .from('stok_gerobak')
          .update({
            'stok_saat_ini': stock,
          })
          .eq('menu_id', menuId)
          .eq('gerobak_id', gerobakId);
    }
  }

  Future<void> increaseStock({
    required String menuId,
    required String gerobakId,
    required int qty,
  }) async {
    final currentStock = await getStockByMenuAndGerobak(
      menuId: menuId,
      gerobakId: gerobakId,
    );

    final newStock = currentStock + qty;

    await updateStock(
      menuId: menuId,
      gerobakId: gerobakId,
      stock: newStock,
    );
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
        .from('stok_gerobak')
        .select('id')
        .eq('menu_id', menuId)
        .eq('gerobak_id', gerobakId)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('stok_gerobak').insert({
        'menu_id': menuId,
        'gerobak_id': gerobakId,
        'stok_awal': stock,
        'stok_saat_ini': stock,
      });
    }
  }

  Future<void> resetStockIfNewDay() async {
    final lastReset = await _getLastResetDate();
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Jika sudah pernah reset hari ini, skip
    if (lastReset == todayStr) return;

    try {
      // Reset stok_saat_ini ke stok_awal masing-masing item
      final stocks = await supabase
          .from('stok_gerobak')
          .select('id, stok_awal');

      for (final item in stocks) {
        final stokAwal = (item['stok_awal'] ?? 10) as int;
        await supabase
            .from('stok_gerobak')
            .update({'stok_saat_ini': stokAwal})
            .eq('id', item['id']);
      }

      await _saveLastResetDate(todayStr);
    } catch (e) {
      debugPrint('resetStockIfNewDay error: $e');
    }
  }

  Future<String?> _getLastResetDate() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      final result = await supabase
          .from('app_settings')
          .select('value')
          .eq('key', 'last_stock_reset_date')
          .maybeSingle();
      return result?['value']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastResetDate(String dateStr) async {
    try {
      await supabase.from('app_settings').upsert({
        'key': 'last_stock_reset_date',
        'value': dateStr,
      }, onConflict: 'key');
    } catch (e) {
      debugPrint('_saveLastResetDate error: $e');
    }
  }
}