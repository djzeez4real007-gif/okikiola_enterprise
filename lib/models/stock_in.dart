class StockInLine {
  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final double quantity;
  final double unitCost;
  final double previousQty;

  StockInLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.unitCost,
    required this.previousQty,
  });

  double get lineCost => quantity * unitCost;
  double get newQty => previousQty + quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'unit': unit,
        'quantity': quantity,
        'unitCost': unitCost,
        'previousQty': previousQty,
      };

  factory StockInLine.fromMap(Map map) => StockInLine(
        productId: map['productId']?.toString() ?? '',
        productName: map['productName']?.toString() ?? '',
        sku: map['sku']?.toString() ?? '',
        unit: map['unit']?.toString() ?? 'pcs',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
        previousQty: (map['previousQty'] as num?)?.toDouble() ?? 0,
      );
}

class StockInRecord {
  final String id;
  final String supplier;
  final String reference; // invoice / delivery note
  final String reason;
  final List<StockInLine> lines;
  final double totalCost;
  final String receivedById;
  final String receivedByName;
  final String receivedAt;
  final String note;

  StockInRecord({
    required this.id,
    required this.supplier,
    required this.reference,
    required this.reason,
    required this.lines,
    required this.totalCost,
    required this.receivedById,
    required this.receivedByName,
    required this.receivedAt,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier': supplier,
        'reference': reference,
        'reason': reason,
        'lines': lines.map((e) => e.toMap()).toList(),
        'totalCost': totalCost,
        'receivedById': receivedById,
        'receivedByName': receivedByName,
        'receivedAt': receivedAt,
        'note': note,
      };

  factory StockInRecord.fromMap(Map map) {
    final raw = map['lines'] as List? ?? [];
    return StockInRecord(
      id: map['id']?.toString() ?? '',
      supplier: map['supplier']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      reason: map['reason']?.toString() ?? 'Purchase',
      lines: raw
          .map((e) => StockInLine.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0,
      receivedById: map['receivedById']?.toString() ?? '',
      receivedByName: map['receivedByName']?.toString() ?? '',
      receivedAt: map['receivedAt']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
    );
  }

  static const reasons = [
    'Purchase',
    'Supplier delivery',
    'Return to stock',
    'Transfer in',
    'Opening balance',
    'Correction',
    'Other',
  ];
}
