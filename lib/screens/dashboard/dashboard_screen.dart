import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/expense_storage.dart';
import '../../services/location_service.dart';
import '../../services/product_storage.dart';
import '../../services/sale_storage.dart';
import '../../services/shift_storage.dart';
import '../../services/cash_movement_storage.dart';
import '../../services/data_refresh.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = true;
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  // Today KPIs
  double todaySales = 0;
  double todayCash = 0;
  double todayTransfer = 0;
  double todayPos = 0;
  double todayExpenses = 0;
  int todaySaleCount = 0;
  int todayItemsSold = 0;

  // Shift
  bool shiftOpen = false;
  double openingCash = 0;
  String shiftSince = '';

  // Inventory
  int productCount = 0;
  int lowStock = 0;
  double stockValue = 0;

  // Owner extras
  double monthSales = 0;
  double monthExpenses = 0;
  List<Map<String, dynamic>> topToday = [];

  String get role => AuthService.currentRole;
  bool get isOwner => role == 'owner' || role == 'manager';
  bool get isSales => role == 'sales';

  @override
  void initState() {
    super.initState();
    LocationService.currentListenable.addListener(_onLocationChanged);
    DataRefresh.tick.addListener(_onDataRefresh);
    load();
  }

  void _onLocationChanged() => load();
  void _onDataRefresh() => load();

  @override
  void dispose() {
    LocationService.currentListenable.removeListener(_onLocationChanged);
    DataRefresh.tick.removeListener(_onDataRefresh);
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final now = DateTime.now();
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    try {
      await ShiftStorage.autoCloseStaleShifts();
    } catch (_) {}

    final sales = await SaleStorage.getAll();
    double tSales = 0, tCash = 0, tTr = 0, tPos = 0, mSales = 0;
    int tCount = 0, tItems = 0;
    final Map<String, Map<String, dynamic>> sold = {};

    final currentLocId = LocationService.currentId ?? '';
    String? defaultLocId;
    for (final l in LocationService.all()) {
      if (l.isDefault) {
        defaultLocId = l.id;
        break;
      }
    }

    for (final s in sales) {
      if (s.voided) continue;
      // Scope to current working location (old sales without location → default shop)
      final saleLoc = s.locationId.isNotEmpty
          ? s.locationId
          : (defaultLocId ?? '');
      if (currentLocId.isNotEmpty &&
          saleLoc.isNotEmpty &&
          saleLoc != currentLocId) {
        continue;
      }
      final mine = !isSales ||
          s.soldById == (AuthService.currentUser?.id ?? '') ||
          s.soldById.isEmpty;

      if (s.createdAt.startsWith(dayKey)) {
        if (isOwner || mine) {
          tSales += s.total;
          tCash += s.cashPaid;
          tTr += s.transferPaid;
          tPos += s.posPaid;
          tCount++;
          for (final it in s.items) {
            tItems += it.quantity.round();
            final k = it.productId.isNotEmpty ? it.productId : it.productName;
            final row = sold.putIfAbsent(
              k,
              () => {'name': it.productName, 'qty': 0.0},
            );
            row['qty'] = (row['qty'] as double) + it.quantity;
          }
        }
      }
      if (s.createdAt.startsWith(monthKey) && isOwner) {
        mSales += s.total;
      }
    }

    final ranked = sold.values.toList()
      ..sort((a, b) => (b['qty'] as double).compareTo(a['qty'] as double));

    double tExp = 0, mExp = 0;
    final expenses = await ExpenseStorage.getAll();
    for (final e in expenses) {
      if (e.date.startsWith(dayKey)) tExp += e.amount;
      if (e.date.startsWith(monthKey)) mExp += e.amount;
    }

    final uid = AuthService.currentUser?.id ?? '';
    final open = await ShiftStorage.currentOpenShift(userId: uid);
    double openCash = 0;
    String since = '';
    if (open != null) {
      openCash = open.openingCash;
      try {
        since = DateFormat('HH:mm').format(DateTime.parse(open.openedAt));
      } catch (_) {
        since = '';
      }
    }

    final products = await ProductStorage.getAll();
    final active = products.where((p) => p.active).toList();
    int low = 0;
    double value = 0;
    for (final p in active) {
      final q = LocationService.currentId != null
          ? LocationService.getStockCurrent(p.id)
          : p.quantity;
      value += q * p.costPrice;
      if (q <= p.reorderLevel) low++;
    }

    if (!mounted) return;
    setState(() {
      todaySales = tSales;
      todayCash = tCash;
      todayTransfer = tTr;
      todayPos = tPos;
      todaySaleCount = tCount;
      todayItemsSold = tItems;
      todayExpenses = tExp;
      monthSales = mSales;
      monthExpenses = mExp;
      shiftOpen = open != null;
      openingCash = openCash;
      shiftSince = since;
      productCount = active.length;
      lowStock = low;
      stockValue = value;
      topToday = ranked.take(5).toList();
      loading = false;
    });
  }


  Future<void> _openShiftFromDash() async {
    final suggested = await ShiftStorage.suggestedOpeningCash();
    final ctrl = TextEditingController(text: suggested.toStringAsFixed(0));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Open shift',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                  'Opening float is pre-filled from last closed shift.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Opening cash (₦)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('OPEN SHIFT',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    final amount = double.tryParse(ctrl.text) ?? 0;
    try {
      await ShiftStorage.openShift(openingCash: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift opened'),
          backgroundColor: AppColors.success,
        ),
      );
      load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _closeShiftFromDash() async {
    final uid = AuthService.currentUser?.id;
    final open = await ShiftStorage.currentOpenShift(userId: uid);
    if (open == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open shift')),
      );
      return;
    }
    final ctrl = TextEditingController(
      text: open.openingCash.toStringAsFixed(0),
    );
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Close shift',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                  'Count the cash in the drawer and enter the total.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cash counted (₦)',
                    prefixIcon: Icon(Icons.savings_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('CLOSE SHIFT',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    final counted = double.tryParse(ctrl.text) ?? 0;
    try {
      await ShiftStorage.closeShift(shift: open, closingCashCounted: counted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift closed'),
          backgroundColor: AppColors.success,
        ),
      );
      load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }


  Future<void> _cashOutFromDash() async {
    if (!shiftOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a shift first')),
      );
      return;
    }
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Owner cash pickup');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cash out from drawer',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the amount removed from the till (not a sale). '
                  'This is used when closing the shift.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₦) *',
                    prefixIcon: Icon(Icons.money_off_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text(
                    'RECORD CASH OUT',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      await CashMovementStorage.addOut(
        amount: amount,
        reason: reasonCtrl.text.trim().isEmpty
            ? 'Owner cash pickup'
            : reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cash out recorded: ${money.format(amount)}'),
          backgroundColor: AppColors.success,
        ),
      );
      load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.currentName;
    final loc = LocationService.current?.name ?? 'Shop';
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Hero
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF042F2E),
                          Color(0xFF0F766E),
                          Color(0xFF14B8A6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greet,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _pill(AppUser.roleLabel(role)),
                                      _pill(loc),
                                      _pill(DateFormat('EEE, dd MMM')
                                          .format(DateTime.now())),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        if (isOwner) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Today\'s net',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            money.format(todaySales - todayExpenses),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Sales ${money.format(todaySales)} − Expenses ${money.format(todayExpenses)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        // Shift controls — sales boy (and useful for everyone)
                        const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      shiftOpen
                                          ? Icons.check_circle_rounded
                                          : Icons.warning_amber_rounded,
                                      color: shiftOpen
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFFFCD34D),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        shiftOpen
                                            ? 'Shift open since $shiftSince · float ${money.format(openingCash)}'
                                            : 'Shift closed — open before selling',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (!shiftOpen)
                                  SizedBox(
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      onPressed: _openShiftFromDash,
                                      icon: const Icon(Icons.play_arrow_rounded),
                                      label: const Text(
                                        'OPEN SHIFT',
                                        style: TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  SizedBox(
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      onPressed: _closeShiftFromDash,
                                      icon: const Icon(Icons.stop_rounded),
                                      label: const Text(
                                        'CLOSE SHIFT',
                                        style: TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF59E0B),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      onPressed: _cashOutFromDash,
                                      icon: const Icon(Icons.money_off_rounded,
                                          color: Colors.white),
                                      label: const Text(
                                        'CASH OUT',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.white70),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Today strip
                  Text(
                    isSales ? 'Your sales today' : 'Today at a glance',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _kpi(
                        'Sales',
                        money.format(todaySales),
                        Icons.trending_up_rounded,
                        AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      _kpi(
                        'Tickets',
                        '$todaySaleCount',
                        Icons.receipt_long_rounded,
                        const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _kpi(
                        'Items sold',
                        '$todayItemsSold',
                        Icons.shopping_bag_outlined,
                        const Color(0xFF0EA5E9),
                      ),
                      const SizedBox(width: 10),
                      _kpi(
                        isSales ? 'Float' : 'Expenses',
                        isSales
                            ? money.format(openingCash)
                            : money.format(todayExpenses),
                        isSales
                            ? Icons.account_balance_wallet_outlined
                            : Icons.payments_outlined,
                        isSales ? AppColors.accent : AppColors.danger,
                      ),
                    ],
                  ),

                  if (isOwner) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Payment mix today',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _paymentBar(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _miniPay('Cash', todayCash, const Color(0xFF059669)),
                        const SizedBox(width: 8),
                        _miniPay(
                            'Transfer', todayTransfer, const Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        _miniPay('POS', todayPos, const Color(0xFFD97706)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'This month',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _kpi(
                          'Sales',
                          money.format(monthSales),
                          Icons.calendar_month_rounded,
                          AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        _kpi(
                          'Expenses',
                          money.format(monthExpenses),
                          Icons.outbox_rounded,
                          AppColors.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _wideCard(
                      'Month net',
                      money.format(monthSales - monthExpenses),
                      (monthSales - monthExpenses) >= 0
                          ? AppColors.success
                          : AppColors.danger,
                      Icons.account_balance_rounded,
                    ),
                  ],

                  const SizedBox(height: 18),
                  const Text(
                    'Inventory pulse',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _kpi(
                        'Products',
                        '$productCount',
                        Icons.inventory_2_rounded,
                        const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 10),
                      _kpi(
                        'Low stock',
                        '$lowStock',
                        Icons.notification_important_rounded,
                        lowStock > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ],
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 10),
                    _wideCard(
                      'Stock value ($loc)',
                      money.format(stockValue),
                      const Color(0xFF0EA5E9),
                      Icons.savings_rounded,
                    ),
                  ],

                  if (topToday.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Top sellers today',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...topToday.asMap().entries.map((e) {
                      final i = e.key + 1;
                      final r = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
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
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: Text(
                                '$i',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${r['name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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
                  ],

                  if (isSales) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick checklist',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text('1. Open shift with starting cash'),
                          Text('2. Record every sale (cash / transfer / POS)'),
                          Text('3. Log expenses when needed'),
                          Text('4. Close shift before 11:59 PM'),
                          SizedBox(height: 8),
                          Text(
                            'Pull down to refresh figures.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Pull down to refresh · Data for $loc',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideCard(String label, String value, Color color, IconData icon) {
    return Container(
      width: double.infinity,
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
            width: 44,
            height: 44,
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
                  label,
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
                    fontSize: 20,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBar() {
    final total = todayCash + todayTransfer + todayPos;
    if (total <= 0) {
      return Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            if (todayCash > 0)
              Expanded(
                flex: (todayCash * 1000).round().clamp(1, 100000),
                child: Container(color: const Color(0xFF059669)),
              ),
            if (todayTransfer > 0)
              Expanded(
                flex: (todayTransfer * 1000).round().clamp(1, 100000),
                child: Container(color: const Color(0xFF2563EB)),
              ),
            if (todayPos > 0)
              Expanded(
                flex: (todayPos * 1000).round().clamp(1, 100000),
                child: Container(color: const Color(0xFFD97706)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniPay(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 6),
            Text(
              money.format(amount),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
