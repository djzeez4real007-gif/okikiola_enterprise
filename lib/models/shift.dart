class Shift {
  final String id;
  final String userId;
  final String userName;
  final String role;
  final String openedAt;
  final double openingCash;
  final String? closedAt;
  final double? closingCashCounted;
  final double? expectedCash;
  final double? cashVariance; // counted - expected (negative = shortage)
  final double? salesTotal;
  final int? salesCount;
  final String note;
  final bool closed;

  Shift({
    required this.id,
    required this.userId,
    required this.userName,
    required this.role,
    required this.openedAt,
    required this.openingCash,
    this.closedAt,
    this.closingCashCounted,
    this.expectedCash,
    this.cashVariance,
    this.salesTotal,
    this.salesCount,
    this.note = '',
    this.closed = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'role': role,
        'openedAt': openedAt,
        'openingCash': openingCash,
        'closedAt': closedAt,
        'closingCashCounted': closingCashCounted,
        'expectedCash': expectedCash,
        'cashVariance': cashVariance,
        'salesTotal': salesTotal,
        'salesCount': salesCount,
        'note': note,
        'closed': closed,
      };

  factory Shift.fromMap(Map map) => Shift(
        id: map['id']?.toString() ?? '',
        userId: map['userId']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        role: map['role']?.toString() ?? '',
        openedAt: map['openedAt']?.toString() ?? '',
        openingCash: (map['openingCash'] as num?)?.toDouble() ?? 0,
        closedAt: map['closedAt']?.toString(),
        closingCashCounted: (map['closingCashCounted'] as num?)?.toDouble(),
        expectedCash: (map['expectedCash'] as num?)?.toDouble(),
        cashVariance: (map['cashVariance'] as num?)?.toDouble(),
        salesTotal: (map['salesTotal'] as num?)?.toDouble(),
        salesCount: (map['salesCount'] as num?)?.toInt(),
        note: map['note']?.toString() ?? '',
        closed: map['closed'] == true,
      );
}
