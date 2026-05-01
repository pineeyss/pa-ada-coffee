import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient supabase = Supabase.instance.client;

  // =============================
  // 🔥 DAILY (HARI INI)
  // =============================

  Future<int> getTotalRevenue({
    String? gerobakId,
  }) async {
    final response = await supabase
        .from('transaksi')
        .select('total_harga, tanggal')
        .eq('gerobak_id', gerobakId!);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    int total = 0;

    for (final item in response) {
      final date = DateTime.tryParse(item['tanggal'] ?? '');
      if (date == null) continue;

      if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end)) {
        total += ((item['total_harga'] ?? 0) as num).toInt();
      }
    }

    return total;
  }

  Future<int> getTotalOrders({
    String? gerobakId,
  }) async {
    final response = await supabase
        .from('transaksi')
        .select('id, tanggal')
        .eq('gerobak_id', gerobakId!);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    int total = 0;

    for (final item in response) {
      final date = DateTime.tryParse(item['tanggal'] ?? '');
      if (date == null) continue;

      if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end)) {
        total++;
      }
    }

    return total;
  }

  Future<List<Map<String, dynamic>>> getTopSellingToday({
    String? gerobakId,
  }) async {
    final transaksi = await supabase
        .from('transaksi')
        .select('id, tanggal')
        .eq('gerobak_id', gerobakId!);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final transaksiToday = transaksi.where((item) {
      final date = DateTime.tryParse(item['tanggal'] ?? '');
      if (date == null) return false;

      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end);
    }).toList();

    if (transaksiToday.isEmpty) return [];

    final ids = transaksiToday.map((e) => e['id']).toList();

    final details = await supabase
        .from('detail_transaksi')
        .select('qty, menu(name)')
        .inFilter('transaksi_id', ids);

    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in details) {
      final name = item['menu']?['name'] ?? '-';
      final qty = ((item['qty'] ?? 0) as num).toInt();

      grouped.putIfAbsent(name, () => {
            'name': name,
            'qty': 0,
          });

      grouped[name]!['qty'] += qty;
    }

    final result = grouped.values.toList();
    result.sort((a, b) => b['qty'].compareTo(a['qty']));

    return result;
  }

  Future<List<Map<String, dynamic>>> getRecentSalesToday({
    String? gerobakId,
  }) async {
    final transaksi = await supabase
        .from('transaksi')
        .select('total_harga, tanggal')
        .eq('gerobak_id', gerobakId!)
        .order('tanggal', ascending: false);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final today = transaksi.where((item) {
      final date = DateTime.tryParse(item['tanggal'] ?? '');
      if (date == null) return false;

      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end);
    }).toList();

    return today.map((e) {
      return {
        'name': 'Transaksi',
        'qty': 1,
        'total': (e['total_harga'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }
}