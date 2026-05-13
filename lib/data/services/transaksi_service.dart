import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaksi_model.dart';
import '../models/detail_transaksi_model.dart';

class TransaksiService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<String> createTransaksi(TransaksiModel transaksi) async {
    final response = await supabase
        .from('transaksi')
        .insert(transaksi.toMap())
        .select()
        .single();

    return response['id'];
  }

  Future<void> addDetail(DetailTransaksiModel detail) async {
    await supabase.from('detail_transaksi').insert(detail.toMap());
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final response = await supabase
        .from('transaksi')
        .select()
        .eq('status', 'pending')
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateStatus(String id, String status) async {
    await supabase
        .from('transaksi')
        .update({'status': status})
        .eq('id', id);
  }
}