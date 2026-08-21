class StockCountLine {
  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final double systemQty;
  final double countedQty;
  final double costPrice;

  StockCountLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.systemQty,
    required this.countedQty,
    required this.costPrice,
  });

  double get variance => countedQty - systemQty;
  double get varianceValue => variance * costPrice;
  bool get hasVariance => variance.abs() > 0.0001;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'unit': unit,
        'systemQty': systemQty,
        'countedQty': countedQty,
        'costPrice': costPrice,
      };

  factory StockCountLine.fromMap(Map map) => StockCountLine(
        productId: map['productId']?.toString() ?? '',
        productName: map['productName']?.toString() ?? '',
        sku: map['sku']?.toString() ?? '',
        unit: map['unit']?.toString() ?? 'pcs',
        systemQty: (map['systemQty'] as num?)?.toDouble() ?? 0,
        countedQty: (map['countedQty'] as num?)?.toDouble() ?? 0,
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
      );
}

class StockCountSession {
  final String id;
  final String status; // draft | completed
  final String startedAt;
  final String? completedAt;
  final String startedById;
  final String startedByName;
  final List<StockCountLine> lines;
  final String note;
  final bool appliedToStock; // if variances written to inventory

  StockCountSession({
    required this.id,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.startedById,
    required this.startedByName,
    required this.lines,
    this.note = '',
    this.appliedToStock = false,
  });

  double get totalShrinkValue => lines.fold(
        0.0,
        (s, l) => s + (l.variance < 0 ? -l.varianceValue : 0),
      );

  double get totalOverValue => lines.fold(
        0.0,
        (s, l) => s + (l.variance > 0 ? l.varianceValue : 0),
      );

  int get varianceLines => lines.where((l) => l.hasVariance).length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'status': status,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'startedById': startedById,
        'startedByName': startedByName,
        'lines': lines.map((e) => e.toMap()).toList(),
        'note': note,
        'appliedToStock': appliedToStock,
      };

  factory StockCountSession.fromMap(Map map) {
    final raw = map['lines'] as List? ?? [];
    return StockCountSession(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'draft',
      startedAt: map['startedAt']?.toString() ?? '',
      completedAt: map['completedAt']?.toString(),
      startedById: map['startedById']?.toString() ?? '',
      startedByName: map['startedByName']?.toString() ?? '',
      lines: raw
          .map((e) => StockCountLine.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      note: map['note']?.toString() ?? '',
      appliedToStock: map['appliedToStock'] == true,
    );
  }
}
