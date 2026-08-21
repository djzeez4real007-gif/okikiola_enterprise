class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final String paymentMethod; // Cash | Transfer | POS
  final String date; // ISO date
  final String note;
  final String recordedById;
  final String recordedByName;
  final String recordedByRole;
  final String createdAt;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    this.note = '',
    required this.recordedById,
    required this.recordedByName,
    required this.recordedByRole,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'date': date,
        'note': note,
        'recordedById': recordedById,
        'recordedByName': recordedByName,
        'recordedByRole': recordedByRole,
        'createdAt': createdAt,
      };

  factory Expense.fromMap(Map map) => Expense(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        category: map['category']?.toString() ?? 'General',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: map['paymentMethod']?.toString() ?? 'Cash',
        date: map['date']?.toString() ?? '',
        note: map['note']?.toString() ?? '',
        recordedById: map['recordedById']?.toString() ?? '',
        recordedByName: map['recordedByName']?.toString() ?? '',
        recordedByRole: map['recordedByRole']?.toString() ?? '',
        createdAt: map['createdAt']?.toString() ?? '',
      );

  static const categories = [
    'Rent',
    'Utilities',
    'Transport',
    'Salaries',
    'Supplies',
    'Maintenance',
    'Marketing',
    'Tax / Levy',
    'Petty cash',
    'General',
    'Other',
  ];
}
