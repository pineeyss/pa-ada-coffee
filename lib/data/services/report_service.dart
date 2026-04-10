import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient supabase = Supabase.instance.client;

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  ({DateTime start, DateTime end}) _getRange({required int days}) {
    final now = DateTime.now();
    final end = _endOfDay(now);
    final start = _startOfDay(now.subtract(Duration(days: days - 1)));
    return (start: start, end: end);
  }

  Future<int> getTotalRevenue({
    String? gerobakId,
    int days = 1,
  }) async {
    final range = _getRange(days: days);

    final List<dynamic> response;
    if (gerobakId != null && gerobakId != 'all') {
      response = await supabase
          .from('transaksi')
          .select('total_harga')
          .eq('gerobak_id', gerobakId)
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String());
    } else {
      response = await supabase
          .from('transaksi')
          .select('total_harga')
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String());
    }

    int total = 0;
    for (final item in response) {
      total += ((item['total_harga'] ?? 0) as num).toInt();
    }
    return total;
  }

  Future<int> getTotalOrders({
    String? gerobakId,
    int days = 1,
  }) async {
    final range = _getRange(days: days);

    final List<dynamic> response;
    if (gerobakId != null && gerobakId != 'all') {
      response = await supabase
          .from('transaksi')
          .select('id')
          .eq('gerobak_id', gerobakId)
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String());
    } else {
      response = await supabase
          .from('transaksi')
          .select('id')
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String());
    }

    return response.length;
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems({
    String? gerobakId,
    int days = 1,
  }) async {
    final range = _getRange(days: days);

    final List<dynamic> transaksi;
    if (gerobakId != null && gerobakId != 'all') {
      transaksi = await supabase
          .from('transaksi')
          .select('id')
          .eq('gerobak_id', gerobakId)
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String());
    } else {
      transaksi = await supabase
          .from('transaksi')
          .select('id')
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String());
    }

    if (transaksi.isEmpty) return [];

    final transaksiIds = transaksi.map((e) => e['id'] as String).toList();

    final detailResponse = await supabase
        .from('detail_transaksi')
        .select('menu_id, qty, harga, transaksi_id')
        .inFilter('transaksi_id', transaksiIds);

    final menuResponse = await supabase.from('menu').select('id, name');

    final Map<String, String> menuMap = {
      for (final item in menuResponse)
        item['id'] as String: item['name'] as String,
    };

    final Map<String, int> soldMap = {};
    final Map<String, int> revenueMap = {};

    for (final item in detailResponse) {
      final menuId = item['menu_id'] as String;
      final qty = ((item['qty'] ?? 0) as num).toInt();
      final harga = ((item['harga'] ?? 0) as num).toInt();

      soldMap[menuId] = (soldMap[menuId] ?? 0) + qty;
      revenueMap[menuId] = (revenueMap[menuId] ?? 0) + (qty * harga);
    }

    final result = soldMap.entries.map((entry) {
      final menuId = entry.key;
      return {
        'menu_id': menuId,
        'name': menuMap[menuId] ?? 'Unknown',
        'qty': entry.value,
        'revenue': revenueMap[menuId] ?? 0,
      };
    }).toList();

    result.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    return result.take(5).toList();
  }

  Future<List<FlSpot>> getSalesTrend({
    String? gerobakId,
    int days = 1,
  }) async {
    final range = _getRange(days: days);

    final List<dynamic> response;
    if (gerobakId != null && gerobakId != 'all') {
      response = await supabase
          .from('transaksi')
          .select('tanggal, total_harga')
          .eq('gerobak_id', gerobakId)
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String())
          .order('tanggal', ascending: true);
    } else {
      response = await supabase
          .from('transaksi')
          .select('tanggal, total_harga')
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String())
          .order('tanggal', ascending: true);
    }

    if (days == 1) {
      final List<int> hourlyTotals = List.filled(24, 0);

      for (final item in response) {
        final rawDate = item['tanggal'];
        final date = DateTime.tryParse(rawDate.toString());
        if (date == null) continue;

        hourlyTotals[date.hour] += ((item['total_harga'] ?? 0) as num).toInt();
      }

      return List.generate(
        24,
        (index) => FlSpot(index.toDouble(), hourlyTotals[index].toDouble()),
      );
    }

    final List<int> dailyTotals = List.filled(days, 0);

    for (final item in response) {
      final rawDate = item['tanggal'];
      final date = DateTime.tryParse(rawDate.toString());
      if (date == null) continue;

      final diff = _startOfDay(date).difference(_startOfDay(range.start)).inDays;
      if (diff >= 0 && diff < days) {
        dailyTotals[diff] += ((item['total_harga'] ?? 0) as num).toInt();
      }
    }

    return List.generate(
      days,
      (index) => FlSpot(index.toDouble(), dailyTotals[index].toDouble()),
    );
  }

  Future<List<Map<String, dynamic>>> getRecentSales({
    String? gerobakId,
    int days = 1,
  }) async {
    final range = _getRange(days: days);

    final List<dynamic> transaksiToday;
    if (gerobakId != null && gerobakId != 'all') {
      transaksiToday = await supabase
          .from('transaksi')
          .select('id, tanggal, gerobak_id')
          .eq('gerobak_id', gerobakId)
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String())
          .order('tanggal', ascending: false);
    } else {
      transaksiToday = await supabase
          .from('transaksi')
          .select('id, tanggal, gerobak_id')
          .gte('tanggal', range.start.toIso8601String())
          .lte('tanggal', range.end.toIso8601String())
          .order('tanggal', ascending: false);
    }

    if (transaksiToday.isEmpty) return [];

    final transaksiMap = {
      for (final trx in transaksiToday) trx['id'] as String: trx,
    };

    final transaksiIds = transaksiMap.keys.toList();

    final detailResponse = await supabase
        .from('detail_transaksi')
        .select('qty, harga, transaksi_id, menu_id')
        .inFilter('transaksi_id', transaksiIds);

    final menuResponse = await supabase.from('menu').select('id, name');

    final Map<String, String> menuMap = {
      for (final item in menuResponse)
        item['id'] as String: item['name'] as String,
    };

    final result = detailResponse.map<Map<String, dynamic>>((item) {
      final menuId = item['menu_id'] as String;
      final qty = ((item['qty'] ?? 0) as num).toInt();
      final harga = ((item['harga'] ?? 0) as num).toInt();
      final trxId = item['transaksi_id'] as String;
      final trxData = transaksiMap[trxId] as Map<String, dynamic>? ?? {};

      final rawDate = trxData['tanggal'];
      final trxGerobakId = (trxData['gerobak_id'] ?? 'owner').toString();

      return {
        'name': menuMap[menuId] ?? 'Unknown',
        'location': _getGerobakName(trxGerobakId),
        'price': harga * qty,
        'time': _formatTime(rawDate),
        'rawDate': rawDate,
      };
    }).toList();

    result.sort((a, b) {
      final dateA = DateTime.tryParse(a['rawDate'].toString()) ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['rawDate'].toString()) ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return result.take(10).toList();
  }

  String getRangeLabel(int days) {
    if (days == 1) {
      return 'Hari ini';
    }
    return '7 hari terakhir';
  }

  String getTrendBottomLabel(double value, int days) {
    if (days == 1) {
      final hour = value.toInt();
      if (hour % 6 != 0) return '';
      return '${hour.toString().padLeft(2, '0')}:00';
    }

    const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final now = DateTime.now();
    final start = _startOfDay(now.subtract(Duration(days: days - 1)));
    final date = start.add(Duration(days: value.toInt()));
    return dayNames[date.weekday - 1];
  }

  String _getGerobakName(String gerobakId) {
    switch (gerobakId) {
      case 'owner':
        return 'Rumah Owner';
      case 'gerobak_1':
        return 'Gerobak 1';
      case 'gerobak_2':
        return 'Gerobak 2';
      case 'gerobak_3':
        return 'Gerobak 3';
      default:
        return 'Unknown';
    }
  }

  String _formatTime(dynamic rawDate) {
    if (rawDate == null) return '-';

    final date = DateTime.tryParse(rawDate.toString());
    if (date == null) return '-';

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}