import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../services/expense_storage.dart';
import '../../services/product_storage.dart';
import '../../services/sale_storage.dart';
import '../../services/shift_storage.dart';
import '../../services/stock_snapshot_storage.dart';
import '../../models/stock_snapshot.dart';

/// Reports with Day / Month / Year filters (multi-year ready).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool loading = true;

  /// day | month | year
  String period = 'day';
  late DateTime selectedDay;
  late int selectedMonth; // 1-12
  late int selectedYear;

  double periodSales = 0;
  double periodExpenses = 0;
  double stockValue = 0;
  int productCount = 0;
  int lowStock = 0;
  double periodCashShort = 0;
  int salesCount = 0;
  int expenseCount = 0;
  double unitsSold = 0;
  bool inventoryFromSnapshot = false;
  String inventoryAsOfLabel = 'Live today';
  StockSnapshot? periodSnapshot;
  List<Map<String, dynamic>> topSellers = [];
  List<Map<String, dynamic>> slowSellers = [];


  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  final years = List.generate(81, (i) => 2020 + i); // 2020–2100

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDay = DateTime(now.year, now.month, now.day);
    selectedMonth = now.month;
    selectedYear = now.year;
    load();
  }

  bool _inPeriod(DateTime dt) {
    switch (period) {
      case 'day':
        return dt.year == selectedDay.year &&
            dt.month == selectedDay.month &&
            dt.day == selectedDay.day;
      case 'month':
        return dt.year == selectedYear && dt.month == selectedMonth;
      case 'year':
        return dt.year == selectedYear;
      default:
        return false;
    }
  }

  bool _dateStringInPeriod(String raw) {
    try {
      // Supports full ISO or yyyy-MM-dd
      final dt = DateTime.parse(raw.length >= 10 ? raw.substring(0, 10) : raw);
      return _inPeriod(DateTime(dt.year, dt.month, dt.day));
    } catch (_) {
      try {
        final dt = DateTime.parse(raw);
        return _inPeriod(dt);
      } catch (_) {
        return false;
      }
    }
  }

  String get periodLabel {
    switch (period) {
      case 'day':
        return DateFormat('dd MMM yyyy').format(selectedDay);
      case 'month':
        return DateFormat('MMMM yyyy')
            .format(DateTime(selectedYear, selectedMonth));
      case 'year':
        return '$selectedYear';
      default:
        return '';
    }
  }

  Future<void> load() async {
    setState(() => loading = true);

    final sales = await SaleStorage.getAll();
    double sTotal = 0;
    int sCount = 0;
    double unitsSoldPeriod = 0;
    final Map<String, Map<String, dynamic>> soldMap = {};
    for (final s in sales) {
      if (s.voided) continue;
      if (!_dateStringInPeriod(s.createdAt)) continue;
      sTotal += s.total;
      sCount++;
      for (final it in s.items) {
        unitsSoldPeriod += it.quantity;
        final key = it.productId.isNotEmpty ? it.productId : it.productName;
        final row = soldMap.putIfAbsent(
          key,
          () => {
            'name': it.productName,
            'qty': 0.0,
            'revenue': 0.0,
          },
        );
        row['qty'] = (row['qty'] as double) + it.quantity;
        row['revenue'] = (row['revenue'] as double) + it.lineTotal;
      }
    }
    final ranked = soldMap.values.toList()
      ..sort((a, b) => (b['qty'] as double).compareTo(a['qty'] as double));
    final top = ranked.take(10).toList();
    final slow = ranked.length <= 10
        ? ranked.reversed.take(ranked.length).toList()
        : ranked.reversed.take(10).toList();
    // Also include products with zero sales in period as slow (optional)
    final productsAll = await ProductStorage.getAll();
    final soldIds = soldMap.keys.toSet();
    final zeroSold = <Map<String, dynamic>>[];
    for (final p in productsAll.where((p) => p.active)) {
      if (!soldIds.contains(p.id) && !soldIds.contains(p.name)) {
        zeroSold.add({'name': p.name, 'qty': 0.0, 'revenue': 0.0});
      }
    }
    zeroSold.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    final slowFinal = [
      ...zeroSold.take(10),
      ...slow.where((e) => (e['qty'] as double) > 0).take(10 - zeroSold.take(10).length),
    ].take(10).toList();

    final expenses = await ExpenseStorage.getAll();
    double eTotal = 0;
    int eCount = 0;
    for (final e in expenses) {
      if (!_dateStringInPeriod(e.date)) continue;
      eTotal += e.amount;
      eCount++;
    }

    // Inventory: prefer snapshot for selected period end date
    String asOfKey;
    if (period == 'day') {
      asOfKey = StockSnapshotStorage.dateKeyFor(selectedDay);
    } else if (period == 'month') {
      final lastDay = DateTime(selectedYear, selectedMonth + 1, 0);
      asOfKey = StockSnapshotStorage.dateKeyFor(lastDay);
    } else {
      asOfKey = '$selectedYear-12-31';
    }

    final snap = await StockSnapshotStorage.asOf(asOfKey);
    double value = 0;
    int low = 0;
    int pCount = 0;
    bool fromSnap = false;
    String invLabel = 'Live today';

    if (snap != null) {
      fromSnap = true;
      invLabel = 'As of ${snap.dateKey}';
      value = snap.totalValue;
      low = snap.lowStockCount;
      pCount = snap.productCount;
    } else {
      final products = await ProductStorage.getAll();
      final active = products.where((p) => p.active).toList();
      pCount = active.length;
      for (final p in active) {
        value += p.stockValue;
        if (p.isLowStock) low++;
      }
    }

    final shifts = await ShiftStorage.getAll();
    double short = 0;
    for (final s in shifts) {
      if (!s.closed) continue;
      try {
        final d = DateTime.parse(s.openedAt);
        if (!_inPeriod(DateTime(d.year, d.month, d.day))) continue;
        final v = s.cashVariance ?? 0;
        if (v < 0) short += -v;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      periodSales = sTotal;
      periodExpenses = eTotal;
      salesCount = sCount;
      expenseCount = eCount;
      unitsSold = unitsSoldPeriod;
      stockValue = value;
      productCount = pCount;
      lowStock = low;
      periodCashShort = short;
      inventoryFromSnapshot = fromSnap;
      inventoryAsOfLabel = invLabel;
      periodSnapshot = snap;
      topSellers = top;
      slowSellers = slowFinal;
      loading = false;
    });
  }

  Future<void> pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      selectedDay = DateTime(picked.year, picked.month, picked.day);
      selectedMonth = picked.month;
      selectedYear = picked.year;
    });
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final net = periodSales - periodExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Header + filters
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Business reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Period type
                Row(
                  children: [
                    _periodChip('day', 'Day'),
                    const SizedBox(width: 8),
                    _periodChip('month', 'Month'),
                    const SizedBox(width: 8),
                    _periodChip('year', 'Year'),
                  ],
                ),
                const SizedBox(height: 12),
                // Date controls
                if (period == 'day')
                  InkWell(
                    onTap: pickDay,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              periodLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Text(
                            'Change',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (period == 'month') ...[
                        Expanded(
                          child: _darkDropdown<int>(
                            value: selectedMonth,
                            items: List.generate(12, (i) => i + 1),
                            label: (m) => DateFormat('MMMM')
                                .format(DateTime(2020, m)),
                            onChanged: (m) async {
                              if (m == null) return;
                              setState(() => selectedMonth = m);
                              await load();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _darkDropdown<int>(
                          value: years.contains(selectedYear)
                              ? selectedYear
                              : years.first,
                          items: years,
                          label: (y) => '$y',
                          onChanged: (y) async {
                            if (y == null) return;
                            setState(() {
                              selectedYear = y;
                              if (period == 'day') {
                                selectedDay = DateTime(
                                  y,
                                  selectedDay.month,
                                  selectedDay.day.clamp(
                                    1,
                                    DateTime(y, selectedDay.month + 1, 0).day,
                                  ),
                                );
                              }
                            });
                            await load();
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  'Net for $periodLabel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  money.format(net),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
                Text(
                  'Sales ${money.format(periodSales)} − Expenses ${money.format(periodExpenses)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        Text(
                          'Period summary',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _card(
                              'Sales',
                              money.format(periodSales),
                              AppColors.primary,
                              Icons.trending_up_rounded,
                              subtitle: '$salesCount sale(s)',
                            ),
                            const SizedBox(width: 10),
                            _card(
                              'Expenses',
                              money.format(periodExpenses),
                              AppColors.danger,
                              Icons.trending_down_rounded,
                              subtitle: '$expenseCount record(s)',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _card(
                              'Net',
                              money.format(net),
                              net >= 0 ? AppColors.success : AppColors.danger,
                              Icons.account_balance_wallet_rounded,
                            ),
                            const SizedBox(width: 10),
                            _card(
                              'Cash short',
                              money.format(periodCashShort),
                              AppColors.accent,
                              Icons.warning_amber_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Period activity',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _card(
                          'Units sold',
                          unitsSold.toStringAsFixed(
                            unitsSold == unitsSold.roundToDouble() ? 0 : 1,
                          ),
                          const Color(0xFF7C3AED),
                          Icons.shopping_bag_outlined,
                          wide: true,
                          subtitle: 'In selected day / month / year',
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Top 10 fast sellers',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (topSellers.isEmpty)
                          const Text('No sales in this period')
                        else
                          ...topSellers.asMap().entries.map((e) {
                            final i = e.key + 1;
                            final r = e.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.15),
                                    child: Text(
                                      '$i',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${r['name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    '${(r['qty'] as double).toStringAsFixed(0)} sold',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 16),
                        const Text(
                          'Slow sellers (incl. no sales)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (slowSellers.isEmpty)
                          const Text('No data')
                        else
                          ...slowSellers.map((r) {
                            final qty = r['qty'] as double;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${r['name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    qty == 0
                                        ? 'No sales'
                                        : '${qty.toStringAsFixed(0)} sold',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: qty == 0
                                          ? AppColors.danger
                                          : AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 18),
                        Text(
                          inventoryFromSnapshot
                              ? 'Inventory ($inventoryAsOfLabel)'
                              : 'Live inventory (today — no snapshot yet)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _card(
                              'Products',
                              '$productCount',
                              const Color(0xFF6366F1),
                              Icons.inventory_2_rounded,
                            ),
                            const SizedBox(width: 10),
                            _card(
                              'Stock value',
                              money.format(stockValue),
                              const Color(0xFF0EA5E9),
                              Icons.savings_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _card(
                          'Low stock items',
                          '$lowStock',
                          lowStock > 0 ? AppColors.danger : AppColors.success,
                          Icons.notification_important_rounded,
                          wide: true,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Inventory figures are current stock (not filtered by date).\n'
                          'Net = sales − expenses for the selected period.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String key, String label) {
    final sel = period == key;
    return Expanded(
      child: Material(
        color: sel ? Colors.white : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            setState(() => period = key);
            await load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: sel ? AppColors.primary : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _darkDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF0F766E),
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(label(e)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _card(
    String title,
    String value,
    Color color,
    IconData icon, {
    bool wide = false,
    String? subtitle,
  }) {
    final child = Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (wide) return child;
    return Expanded(child: child);
  }
}
