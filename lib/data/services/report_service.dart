import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient supabase = Supabase.instance.client;

  String? _resolveSpreadsheetKey({
    String? gerobakId,
    String? gerobakName,
  }) {
    final normalized = (gerobakId ?? gerobakName ?? '')
        .toLowerCase()
        .replaceAll(' ', '_');

    if (normalized.contains('01')) return 'gerobak_01';
    if (normalized.contains('02')) return 'gerobak_02';
    if (normalized.contains('03')) return 'gerobak_03';

    return null;
  }

  // =============================
  // 🔥 DAILY FIX (ANTI 0)
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

  // =============================
  // WEEKLY
  // =============================

  Future<int> getWeeklyRevenue({
    required String? gerobakId,
  }) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final response = await supabase
        .from('transaksi')
        .select('total_harga, tanggal')
        .eq('gerobak_id', gerobakId!)
        .gte('tanggal', sevenDaysAgo.toIso8601String());

    int total = 0;
    for (var item in response) {
      total += (item['total_harga'] as num?)?.toInt() ?? 0;
    }

    return total;
  }

  Future<int> getWeeklyOrders({
    required String? gerobakId,
  }) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final response = await supabase
        .from('transaksi')
        .select('id, tanggal')
        .eq('gerobak_id', gerobakId!)
        .gte('tanggal', sevenDaysAgo.toIso8601String());

    return response.length;
  }

  // =============================
  // HISTORICAL
  // =============================

  Future<List<Map<String, dynamic>>> getHistoricalDailySummaries({
    required String gerobakId,
  }) async {
    final transaksi = await supabase
        .from('transaksi')
        .select('tanggal, total_harga')
        .eq('gerobak_id', gerobakId);

    final formatter = DateFormat('dd/MM/yyyy');
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in transaksi) {
      final date = DateTime.tryParse(item['tanggal'] ?? '');
      if (date == null) continue;

      final key = formatter.format(date);

      grouped.putIfAbsent(key, () => {
            'tanggal': key,
            'totalRevenue': 0,
            'totalOrders': 0,
          });

      grouped[key]!['totalRevenue'] += (item['total_harga'] as num).toInt();
      grouped[key]!['totalOrders'] += 1;
    }

    return grouped.values.map((e) {
      final revenue = e['totalRevenue'];
      final orders = e['totalOrders'];

      return {
        'tanggal': e['tanggal'],
        'gerobakId': gerobakId,
        'totalRevenue': revenue,
        'totalOrders': orders,
        'averageOrderValue':
            orders > 0 ? (revenue / orders).round() : 0,
      };
    }).toList();
  }

  // =============================
  // SPREADSHEET URL
  // =============================

  String? getSpreadsheetUrl({
    required String role,
    String? gerobakId,
    String? gerobakName,
  }) {
    if (role == 'owner') {
      return 'https://docs.google.com/spreadsheets/d/1q0AsTVuUClnVPKluUINe83flIV8EsdDRoMTGQ-OqJ58/edit';
    }

    final key = _resolveSpreadsheetKey(
      gerobakId: gerobakId,
      gerobakName: gerobakName,
    );

    if (key == null) return null;

    const map = {
      'gerobak_01':
          'https://docs.google.com/spreadsheets/d/1963atrAPVOSWEUu6F63dF29moQRXbVCWnqPfxeZZ2zc/edit',
      'gerobak_02':
          'https://docs.google.com/spreadsheets/d/1pQN_M4b-w72e8imMKQbwl9RvFjYhq94BddbFj2839TU/edit',
      'gerobak_03':
          'https://docs.google.com/spreadsheets/d/1goGkG8TB4G-jJRLxRNFaVV90XQHzLEh36y6Og2OKT7g/edit',
    };

    return map[key];
  }

  String? getDownloadUrl({
    required String role,
    String? gerobakId,
    String? gerobakName,
  }) {
    if (role == 'owner') {
      return 'https://docs.google.com/spreadsheets/d/1q0AsTVuUClnVPKluUINe83flIV8EsdDRoMTGQ-OqJ58/export?format=xlsx';
    }

    final key = _resolveSpreadsheetKey(
      gerobakId: gerobakId,
      gerobakName: gerobakName,
    );

    if (key == null) return null;

    const map = {
      'gerobak_01':
          'https://docs.google.com/spreadsheets/d/1963atrAPVOSWEUu6F63dF29moQRXbVCWnqPfxeZZ2zc/export?format=xlsx',
      'gerobak_02':
          'https://docs.google.com/spreadsheets/d/1pQN_M4b-w72e8imMKQbwl9RvFjYhq94BddbFj2839TU/export?format=xlsx',
      'gerobak_03':
          'https://docs.google.com/spreadsheets/d/1goGkG8TB4G-jJRLxRNFaVV90XQHzLEh36y6Og2OKT7g/export?format=xlsx',
    };

    return map[key];
  }
}