class TransaksiModel {
  final String? id;
  final String? gerobakId;
  final String? riderId;
  final int totalHarga;
  final DateTime? tanggal;

  TransaksiModel({
    this.id,
    this.gerobakId,
    this.riderId,
    required this.totalHarga,
    this.tanggal,
  });

  factory TransaksiModel.fromMap(Map<String, dynamic> map) {
    return TransaksiModel(
      id: map['id'] as String?,
      gerobakId: map['gerobak_id'] as String?,
      riderId: map['rider_id'] as String?,
      totalHarga: (map['total_harga'] ?? 0) as int,
      tanggal: map['tanggal'] != null
          ? DateTime.tryParse(map['tanggal'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gerobak_id': gerobakId,
      'rider_id': riderId,
      'total_harga': totalHarga,
    };
  }
}