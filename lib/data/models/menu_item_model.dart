class MenuItemModel {
  final String? id;
  final String name;
  final int price;
  final String category;
  final int stock;
  final String emoji;
  final DateTime? createdAt;

  MenuItemModel({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.stock,
    required this.emoji,
    this.createdAt,
  });

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: map['id'] as String?,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0) as int,
      category: map['category'] ?? '',
      stock: (map['stock'] ?? 0) as int,
      emoji: map['emoji'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'stock': stock,
      'emoji': emoji,
    };
  }
}