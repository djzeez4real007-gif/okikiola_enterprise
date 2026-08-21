class Product {
  final String id;
  final String name;
  final String sku;
  final String category;
  final String unit; // pcs, carton, kg, litre...
  final double costPrice;
  final double sellingPrice;
  final double quantity;
  final double reorderLevel;
  final String description;
  final bool active;
  final String createdAt;
  final String updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.unit,
    required this.costPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.reorderLevel,
    this.description = '',
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => quantity <= reorderLevel;
  double get stockValue => quantity * costPrice;
  double get potentialRevenue => quantity * sellingPrice;
  double get marginPercent {
    if (sellingPrice <= 0) return 0;
    return ((sellingPrice - costPrice) / sellingPrice) * 100;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
        'unit': unit,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'quantity': quantity,
        'reorderLevel': reorderLevel,
        'description': description,
        'active': active,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Product.fromMap(Map map) => Product(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        sku: map['sku']?.toString() ?? '',
        category: map['category']?.toString() ?? 'General',
        unit: map['unit']?.toString() ?? 'pcs',
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
        sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        reorderLevel: (map['reorderLevel'] as num?)?.toDouble() ?? 0,
        description: map['description']?.toString() ?? '',
        active: map['active'] != false,
        createdAt: map['createdAt']?.toString() ?? '',
        updatedAt: map['updatedAt']?.toString() ?? '',
      );

  Product copyWith({
    String? name,
    String? sku,
    String? category,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    double? quantity,
    double? reorderLevel,
    String? description,
    bool? active,
    String? updatedAt,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      description: description ?? this.description,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
