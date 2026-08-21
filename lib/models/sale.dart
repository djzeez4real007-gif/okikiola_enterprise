class SaleItem {
  final String productId;
  final String productName;
  final String sku;
  final double unitPrice;
  final double quantity;
  final double discount;
  final String unit;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0,
    this.unit = 'pcs',
  });

  double get lineTotal => (unitPrice * quantity) - discount;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'discount': discount,
        'unit': unit,
      };

  factory SaleItem.fromMap(Map map) => SaleItem(
        productId: map['productId']?.toString() ?? '',
        productName: map['productName']?.toString() ?? '',
        sku: map['sku']?.toString() ?? '',
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        unit: map['unit']?.toString() ?? 'pcs',
      );
}

class Sale {
  final String id;
  final String receiptNo;
  final List<SaleItem> items;
  final double subtotal;
  final double discountTotal;
  final double total;
  final double amountPaid;
  final String paymentMethod; // Cash | Transfer | POS | Mixed
  /// Split tender amounts (sum should equal amountPaid / total)
  final double cashPaid;
  final double transferPaid;
  final double posPaid;
  final String soldById;
  final String soldByName;
  final String soldByRole;
  final String createdAt;
  final String note;
  final bool voided;
  final String locationId;
  final String locationName;

  Sale({
    required this.id,
    required this.receiptNo,
    required this.items,
    required this.subtotal,
    required this.discountTotal,
    required this.total,
    required this.amountPaid,
    required this.paymentMethod,
    this.cashPaid = 0,
    this.transferPaid = 0,
    this.posPaid = 0,
    required this.soldById,
    required this.soldByName,
    required this.soldByRole,
    required this.createdAt,
    this.note = '',
    this.voided = false,
    this.locationId = '',
    this.locationName = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'receiptNo': receiptNo,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'discountTotal': discountTotal,
        'total': total,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'cashPaid': cashPaid,
        'transferPaid': transferPaid,
        'posPaid': posPaid,
        'soldById': soldById,
        'soldByName': soldByName,
        'soldByRole': soldByRole,
        'createdAt': createdAt,
        'note': note,
        'voided': voided,
        'locationId': locationId,
        'locationName': locationName,
      };

  factory Sale.fromMap(Map map) {
    final rawItems = map['items'] as List? ?? [];
    return Sale(
      id: map['id']?.toString() ?? '',
      receiptNo: map['receiptNo']?.toString() ?? '',
      items: rawItems
          .map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discountTotal: (map['discountTotal'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['paymentMethod']?.toString() ?? 'Cash',
      cashPaid: (map['cashPaid'] as num?)?.toDouble() ?? 0,
      transferPaid: (map['transferPaid'] as num?)?.toDouble() ?? 0,
      posPaid: (map['posPaid'] as num?)?.toDouble() ?? 0,
      soldById: map['soldById']?.toString() ?? '',
      soldByName: map['soldByName']?.toString() ?? '',
      soldByRole: map['soldByRole']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      voided: map['voided'] == true,
    );
  }
}
