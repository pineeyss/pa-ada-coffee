import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<int> getTotalRevenue({String? gerobakId}) async {
    try {
      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toIso8601String();

      var query = supabase
          .from('transaksi')
          .select('total_harga')
          .gte('tanggal', startOfDay)
          .lte('tanggal', endOfDay);

      if (gerobakId != null && gerobakId.isNotEmpty) {
        query = query.eq('gerobak_id', gerobakId);
      }

      final response = await query;

      int total = 0;

      for (final item in response) {
        total += ((item['total_harga'] ?? 0) as num).toInt();
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getTotalOrders({String? gerobakId}) async {
    try {
      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toIso8601String();

      var query = supabase
          .from('transaksi')
          .select('id')
          .gte('tanggal', startOfDay)
          .lte('tanggal', endOfDay);

      if (gerobakId != null && gerobakId.isNotEmpty) {
        query = query.eq('gerobak_id', gerobakId);
      }

      final response = await query;

      return response.length;
    } catch (e) {
      return 0;
    }
  }
}