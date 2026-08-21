class StockSnapshotLine {
  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final String category;
  final double quantity;
  final double costPrice;
  final double sellingPrice;
  final double reorderLevel;

  StockSnapshotLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.category,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    required this.reorderLevel,
  });

  double get stockValue => quantity * costPrice;
  bool get isLowStock => quantity <= reorderLevel;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'unit': unit,
        'category': category,
        'quantity': quantity,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'reorderLevel': reorderLevel,
      };

  factory StockSnapshotLine.fromMap(Map map) => StockSnapshotLine(
        productId: map['productId']?.toString() ?? '',
        productName: map['productName']?.toString() ?? '',
        sku: map['sku']?.toString() ?? '',
        unit: map['unit']?.toString() ?? 'pcs',
        category: map['category']?.toString() ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
        sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0,
        reorderLevel: (map['reorderLevel'] as num?)?.toDouble() ?? 0,
      );
}

class StockSnapshot {
  final String id;
  /// yyyy-MM-dd — one snapshot per day (latest wins if retaken)
  final String dateKey;
  final String takenAt;
  final String takenById;
  final String takenByName;
  final String source; // shift_close | manual | stock_count | auto
  final List<StockSnapshotLine> lines;
  final double totalValue;
  final int productCount;
  final int lowStockCount;

  StockSnapshot({
    required this.id,
    required this.dateKey,
    required this.takenAt,
    required this.takenById,
    required this.takenByName,
    required this.source,
    required this.lines,
    required this.totalValue,
    required this.productCount,
    required this.lowStockCount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateKey': dateKey,
        'takenAt': takenAt,
        'takenById': takenById,
        'takenByName': takenByName,
        'source': source,
        'lines': lines.map((e) => e.toMap()).toList(),
        'totalValue': totalValue,
        'productCount': productCount,
        'lowStockCount': lowStockCount,
      };

  factory StockSnapshot.fromMap(Map map) {
    final raw = map['lines'] as List? ?? [];
    return StockSnapshot(
      id: map['id']?.toString() ?? '',
      dateKey: map['dateKey']?.toString() ?? '',
      takenAt: map['takenAt']?.toString() ?? '',
      takenById: map['takenById']?.toString() ?? '',
      takenByName: map['takenByName']?.toString() ?? '',
      source: map['source']?.toString() ?? 'manual',
      lines: raw
          .map((e) =>
              StockSnapshotLine.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalValue: (map['totalValue'] as num?)?.toDouble() ?? 0,
      productCount: (map['productCount'] as num?)?.toInt() ?? 0,
      lowStockCount: (map['lowStockCount'] as num?)?.toInt() ?? 0,
    );
  }
}
