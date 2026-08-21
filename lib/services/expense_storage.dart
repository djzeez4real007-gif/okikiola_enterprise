import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'data_refresh.dart';
import 'hive_boxes.dart';

class ExpenseStorage {
  static Box get _box => Hive.box(HiveBoxes.expenses);

  static Future<List<Expense>> getAll() async {
    final list = _box.values
        .map((e) => Expense.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<Expense> add({
    required String title,
    required String category,
    required double amount,
    required String paymentMethod,
    required String date,
    String note = '',
  }) async {
    final user = AuthService.currentUser;
    final expense = Expense(
      id: const Uuid().v4(),
      title: title.trim(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      amount: amount,
      paymentMethod: paymentMethod,
      date: date,
      note: note.trim(),
      recordedById: user?.id ?? '',
      recordedByName: user?.name ?? '',
      recordedByRole: user?.role ?? '',
      createdAt: DateTime.now().toIso8601String(),
    );
    await _box.add(expense.toMap());
    DataRefresh.notify();
    await AuditLogStorage.log(
      action: 'expense_added',
      module: 'expenses',
      description:
          '${expense.title}: ₦${expense.amount.toStringAsFixed(0)} ($category) by ${expense.recordedByName}',
      refId: expense.id,
    );
    return expense;
  }

  static Future<void> delete(Expense expense) async {
    final values = _box.values.toList();
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      if (map['id'] == expense.id) {
        await _box.deleteAt(i);
        await AuditLogStorage.log(
          action: 'expense_deleted',
          module: 'expenses',
          description:
              'Deleted ${expense.title} ₦${expense.amount.toStringAsFixed(0)} by ${AuthService.currentName}',
          refId: expense.id,
        );
        return;
      }
    }
  }

  static Future<double> totalForDay(DateTime day) async {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final all = await getAll();
    double t = 0;
    for (final e in all) {
      if (e.date.startsWith(key)) t += e.amount;
    }
    return t;
  }

  static Future<double> totalForMonth(int year, int month) async {
    final prefix =
        '$year-${month.toString().padLeft(2, '0')}';
    final all = await getAll();
    double t = 0;
    for (final e in all) {
      if (e.date.startsWith(prefix)) t += e.amount;
    }
    return t;
  }
}
