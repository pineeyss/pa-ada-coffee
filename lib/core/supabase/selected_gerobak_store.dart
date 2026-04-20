import 'package:flutter/foundation.dart';

class GerobakItem {
  final String id;
  final String namaGerobak;
  final String? lokasi;

  GerobakItem({
    required this.id,
    required this.namaGerobak,
    this.lokasi,
  });

  factory GerobakItem.fromMap(Map<String, dynamic> map) {
    return GerobakItem(
      id: map['id'].toString(),
      namaGerobak: map['nama_gerobak'] ?? '',
      lokasi: map['lokasi'],
    );
  }
}

class SelectedGerobakStore {
  static final ValueNotifier<GerobakItem?> selectedGerobak =
      ValueNotifier<GerobakItem?>(null);

  static final ValueNotifier<int> salesRefreshToken = ValueNotifier<int>(0);

  static void setGerobak(GerobakItem gerobak) {
    selectedGerobak.value = gerobak;
  }

  static void notifySalesChanged() {
    salesRefreshToken.value = salesRefreshToken.value + 1;
  }

  static String? get selectedGerobakId => selectedGerobak.value?.id;
  static String get selectedGerobakName =>
      selectedGerobak.value?.namaGerobak ?? 'Pilih Gerobak';
}