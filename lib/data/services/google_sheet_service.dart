import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GoogleSheetService {
  static const Duration _timeout = Duration(seconds: 20);

  static const String scriptUrl =
    'https://script.google.com/macros/s/AKfycbxf6azlYJZCerIumTqmHu8oEKF1cC5VVtucwZuH8SLCPIPdDX6cE3tmNF3hdtfo7hBK/exec';
  static Future<bool> sendReport({
    required String tanggal,
    required String gerobakId,
    required String gerobakName,
    required String name,
    required String email,
    required String role,
    required int totalRevenue,
    required int totalOrders,
    required int averageOrderValue,
    String syncType = 'daily_summary',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(scriptUrl),
            body: {
              'action': 'sync_report',
              'syncType': syncType,
              'syncKey': '${gerobakId}_$tanggal',
              'tanggal': tanggal,
              'gerobakId': gerobakId,
              'gerobakName': gerobakName,
              'name': name,
              'email': email,
              'role': role,
              'totalRevenue': totalRevenue.toString(),
              'totalOrders': totalOrders.toString(),
              'averageOrderValue': averageOrderValue.toString(),
            },
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint('sendReport status: ${response.statusCode}');
        debugPrint('sendReport body: ${response.body}');
      }

      if (response.statusCode != 200) return false;

      final body = response.body.toLowerCase().trim();
      return body.contains('ok') || body.contains('success');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('sendReport error: $e');
      }
      return false;
    }
  }

  static Future<bool> sendHistoricalReports({
    required List<Map<String, dynamic>> reports,
  }) async {
    if (reports.isEmpty) return true;

    try {
      for (final item in reports) {
        final ok = await sendReport(
          tanggal: item['tanggal']?.toString() ?? '',
          gerobakId: item['gerobakId']?.toString() ?? '',
          gerobakName: item['gerobakName']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          email: item['email']?.toString() ?? '',
          role: item['role']?.toString() ?? '',
          totalRevenue: ((item['totalRevenue'] ?? 0) as num).toInt(),
          totalOrders: ((item['totalOrders'] ?? 0) as num).toInt(),
          averageOrderValue: ((item['averageOrderValue'] ?? 0) as num).toInt(),
          syncType: item['syncType']?.toString() ?? 'historical_summary',
        );

        if (!ok) {
          if (kDebugMode) {
            debugPrint('sendHistoricalReports gagal di item: $item');
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('sendHistoricalReports error: $e');
      }
      return false;
    }
  }
}