import 'package:flutter/material.dart';

import '../core/permissions.dart';
import '../core/theme/app_theme.dart';
import '../models/app_user.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/products/product_list_screen.dart';
import '../screens/sales/pos_screen.dart';
import '../screens/shifts/shifts_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/audit/audit_log_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/stock/stock_count_screen.dart';
import '../screens/stock/stock_in_screen.dart';
import '../screens/stock/stock_snapshots_screen.dart';
import '../screens/locations/locations_screen.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

class _NavItem {
  final String key;
  final IconData icon;
  final String label;
  final Widget page;

  const _NavItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.page,
  });
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    LocationService.currentListenable.addListener(_onLoc);
  }

  @override
  void dispose() {
    LocationService.currentListenable.removeListener(_onLoc);
    super.dispose();
  }

  void _onLoc() {
    if (mounted) setState(() {});
  }

  List<_NavItem> get items {
    final role = AuthService.currentRole;
    final all = <_NavItem>[
      const _NavItem(
        key: Permissions.dashboard,
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        page: DashboardScreen(),
      ),
      const _NavItem(
        key: Permissions.products,
        icon: Icons.inventory_2_rounded,
        label: 'Products',
        page: ProductListScreen(),
      ),
      const _NavItem(
        key: Permissions.stockCount,
        icon: Icons.fact_check_rounded,
        label: 'Stock count',
        page: StockCountScreen(),
      ),
      const _NavItem(
        key: Permissions.stockAdjust,
        icon: Icons.move_to_inbox_rounded,
        label: 'Stock in',
        page: StockInScreen(),
      ),
      const _NavItem(
        key: Permissions.stockCount,
        icon: Icons.photo_library_outlined,
        label: 'Snapshots',
        page: StockSnapshotsScreen(),
      ),
      const _NavItem(
        key: Permissions.sales,
        icon: Icons.point_of_sale_rounded,
        label: 'Sales',
        page: PosScreen(),
      ),
      const _NavItem(
        key: Permissions.expenses,
        icon: Icons.payments_rounded,
        label: 'Expenses',
        page: ExpensesScreen(),
      ),
      const _NavItem(
        key: Permissions.shifts,
        icon: Icons.schedule_rounded,
        label: 'Shifts',
        page: ShiftsScreen(),
      ),
      const _NavItem(
        key: Permissions.reports,
        icon: Icons.bar_chart_rounded,
        label: 'Reports',
        page: ReportsScreen(),
      ),
      const _NavItem(
        key: Permissions.audit,
        icon: Icons.policy_rounded,
        label: 'Audit',
        page: AuditLogScreen(),
      ),
      const _NavItem(
        key: Permissions.users,
        icon: Icons.people_rounded,
        label: 'Users',
        page: UsersScreen(),
      ),
      const _NavItem(
        key: Permissions.settings,
        icon: Icons.storefront_rounded,
        label: 'Locations',
        page: LocationsScreen(),
      ),
    ];
    return all.where((e) => Permissions.canAccess(role, e.key)).toList();
  }

  Widget _placeholder(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_rounded,
                size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = items;
    if (index >= nav.length) index = 0;
    final role = AuthService.currentRole;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(nav[index].label),
            if (LocationService.current != null)
              Text(
                LocationService.current!.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                AppUser.roleLabel(role),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              final ok = await showGeneralDialog<bool>(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Logout',
                barrierColor: Colors.black54,
                transitionDuration: const Duration(milliseconds: 280),
                pageBuilder: (ctx, __, ___) {
                  return Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 320,
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFDC2626),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Sign out?',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'End your session on this device. Cash shifts stay saved.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Stay'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Logout',
                                      style: TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
              if (ok == true) AuthService.logout();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'OKIKIOLA ENTERPRISE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      AuthService.currentName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: nav.length,
                itemBuilder: (context, i) {
                  final item = nav[i];
                  return ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    selected: i == index,
                    onTap: () {
                      setState(() => index = i);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('End this session?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Stay'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (ok == true) AuthService.logout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: nav[index].page,
    );
  }
}
