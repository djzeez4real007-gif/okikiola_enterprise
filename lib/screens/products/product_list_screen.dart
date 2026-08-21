import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/product_storage.dart';
import '../../services/location_service.dart';
import 'product_form_screen.dart';
import '../../services/product_excel_service.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  bool loading = true;
  List<Product> products = [];
  String query = '';
  String filter = 'All'; // All | Low stock | Active

  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  bool get canEdit => Permissions.canEditProduct(AuthService.currentRole);
  bool get canSeeCost =>
      Permissions.canEditCostPrice(AuthService.currentRole) ||
      AuthService.currentRole == 'manager' ||
      AuthService.currentRole == 'owner';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    await LocationService.repairOrphanStock();
    final list = await ProductStorage.getAll();
    if (!mounted) return;
    setState(() {
      products = list;
      loading = false;
    });
  }


  Future<void> _exportExcel() async {
    try {
      final name = await ProductExcelService.exportAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported: $name'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _importExcel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Import products from Excel'),
        content: const Text(
          'Columns: Name, SKU, Category, Unit, Cost Price, Selling Price, '
          'Quantity, Reorder Level, Description, Active.\n\n'
          'Matching SKU will UPDATE the product. New SKUs are created.\n'
          'Quantity applies to the current working location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final result = await ProductExcelService.importFromPicker();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.summary),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
        ),
      );
      if (result.errors.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Some rows failed'),
            content: SingleChildScrollView(
              child: Text(result.errors.join('\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  List<Product> get filtered {
    var list = products.where((p) => p.active).toList();
    if (filter == 'Low stock') {
      list = list.where((p) => p.isLowStock).toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    double _locQty(Product p) => LocationService.currentId != null
        ? LocationService.getStockCurrent(p.id)
        : p.quantity;
    final lowCount =
        products.where((p) => p.active && _locQty(p) <= p.reorderLevel).length;
    final totalQty = products
        .where((p) => p.active)
        .fold<double>(0, (s, p) => s + _locQty(p));
    final stockValue = products.where((p) => p.active).fold<double>(
          0,
          (s, p) => s + (_locQty(p) * p.costPrice),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                );
                if (ok == true) load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add product'),
            )
          : null,
      body: Column(
        children: [
          // Premium header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF0D9488),
                  Color(0xFF14B8A6)
                ],
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
                        'Inventory',
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
                Text(
                  canEdit
                      ? 'Manage products, prices and stock levels'
                      : 'View products available for sale',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _stat('Items', '${products.where((p) => p.active).length}'),
                    const SizedBox(width: 8),
                    _stat('Low stock', '$lowCount', warn: lowCount > 0),
                    const SizedBox(width: 8),
                    _stat('Units', totalQty.toStringAsFixed(0)),
                    if (canSeeCost) ...[
                      const SizedBox(width: 8),
                      _stat('Value', money.format(stockValue)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Search + filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Search name, SKU, category…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportExcel,
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export Excel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _importExcel,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('Import Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'Low stock'].map((f) {
                final selected = filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => filter = f),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              query.isEmpty
                                  ? 'No products yet'
                                  : 'No match for “$query”',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (canEdit && query.isEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Tap + Add product to begin'),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final p = list[i];
                            return _productCard(p);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {bool warn = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: warn ? const Color(0xFFFDE68A) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Product p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canEdit
              ? () async {
                  final idx = await ProductStorage.indexOfId(p.id);
                  if (!mounted) return;
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductFormScreen(
                        product: p,
                        index: idx,
                      ),
                    ),
                  );
                  if (ok == true) load();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _locQty(p) <= p.reorderLevel
                          ? [const Color(0xFFDC2626), const Color(0xFFF97316)]
                          : [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.sku} · ${p.category}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          _badge(
                            '${(LocationService.currentId != null ? LocationService.getStockCurrent(p.id) : p.quantity).toStringAsFixed(0)} ${p.unit}',
                            (LocationService.currentId != null
                                        ? LocationService.getStockCurrent(p.id)
                                        : p.quantity) <=
                                    p.reorderLevel
                                ? const Color(0xFFDC2626)
                                : AppColors.primary,
                          ),
                          _badge(
                            money.format(p.sellingPrice),
                            const Color(0xFFD97706),
                          ),
                          if (_locQty(p) <= p.reorderLevel)
                            _badge('LOW', const Color(0xFFDC2626)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  double _locQty(dynamic product) {
    try {
      final value = product.quantity;

      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(value.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
