import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item_model.dart';

class MenuService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<MenuItemModel>> getMenus() async {
    final response = await supabase
        .from('menu')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => MenuItemModel.fromMap(item))
        .toList();
  }

  Future<void> addMenu(MenuItemModel item) async {
    await supabase.from('menu').insert(item.toMap());
  }

  Future<void> updateMenu(String id, MenuItemModel item) async {
    await supabase.from('menu').update(item.toMap()).eq('id', id);
  }

  Future<void> deleteMenu(String id) async {
    await supabase.from('menu').delete().eq('id', id);
  }
}