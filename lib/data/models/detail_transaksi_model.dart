class DetailTransaksiModel {
  final String? id;
  final String transaksiId;
  final String menuId;
  final int qty;
  final int harga;

  DetailTransaksiModel({
    this.id,
    required this.transaksiId,
    required this.menuId,
    required this.qty,
    required this.harga,
  });

  Map<String, dynamic> toMap() {
    return {
      'transaksi_id': transaksiId,
      'menu_id': menuId,
      'qty': qty,
      'harga': harga,
    };
  }
}