import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/selected_gerobak_store.dart';

class GerobakService {
  final supabase = Supabase.instance.client;

  Future<List<GerobakItem>> fetchGerobakOwner() async {
    final response = await supabase
        .from('gerobak')
        .select('id, nama_gerobak, lokasi')
        .order('nama_gerobak', ascending: true);

    return (response as List)
        .map((e) => GerobakItem.fromMap(e))
        .toList();
  }
}