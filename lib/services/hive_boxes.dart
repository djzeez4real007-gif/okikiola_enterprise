import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const users = 'users';
  static const products = 'products';
  static const sales = 'sales';
  static const expenses = 'expenses';
  static const shifts = 'shifts';
  static const audit = 'audit_logs';
  static const settings = 'settings';
  static const stockCounts = 'stock_counts';
  static const stockIns = 'stock_ins';
  static const stockSnapshots = 'stock_snapshots';
  static const locations = 'locations';
  static const locationStock = 'location_stock';
  static const stockTransfers = 'stock_transfers';
  static const cashMovements = 'cash_movements';

  static Future<void> openAll() async {
    await Future.wait([
      Hive.openBox(users),
      Hive.openBox(products),
      Hive.openBox(sales),
      Hive.openBox(expenses),
      Hive.openBox(shifts),
      Hive.openBox(audit),
      Hive.openBox(settings),
      Hive.openBox(stockCounts),
      Hive.openBox(stockIns),
      Hive.openBox(stockSnapshots),
      Hive.openBox(locations),
      Hive.openBox(locationStock),
      Hive.openBox(stockTransfers),
      Hive.openBox(cashMovements),
    ]);
  }
}
