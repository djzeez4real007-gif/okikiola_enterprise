import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../services/auth_service.dart';
import '../../services/product_storage.dart';
import '../../services/sale_storage.dart';
import '../../services/location_service.dart';
import '../../services/shift_storage.dart';
import 'sale_receipt_screen.dart';
import 'sales_history_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  bool loading = true;
  List<Product> products = [];
  final List<SaleItem> cart = [];
  String query = '';
  bool checkingOut = false;

  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  double get subtotal =>
      cart.fold(0, (s, i) => s + (i.unitPrice * i.quantity));
  double get discountTotal => cart.fold(0, (s, i) => s + i.discount);
  double get total => subtotal - discountTotal;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final list = await ProductStorage.getAll();
    if (!mounted) return;
    setState(() {
      products = list.where((p) {
      if (!p.active) return false;
      final q = LocationService.currentId != null
          ? LocationService.getStockCurrent(p.id)
          : p.quantity;
      return q > 0;
    }).toList();
      loading = false;
    });
  }

  List<Product> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q))
        .toList();
  }

  double _avail(Product p) => LocationService.currentId != null
      ? LocationService.getStockCurrent(p.id)
      : p.quantity;

  void addToCart(Product p) async {
    if (!await _ensureShiftForSales()) return;
    final avail = _avail(p);
    final idx = cart.indexWhere((c) => c.productId == p.id);
    if (idx >= 0) {
      final item = cart[idx];
      if (item.quantity + 1 > avail) {
        _toast('Only $avail ${p.unit} in stock here');
        return;
      }
      setState(() {
        cart[idx] = SaleItem(
          productId: item.productId,
          productName: item.productName,
          sku: item.sku,
          unitPrice: item.unitPrice,
          quantity: item.quantity + 1,
          discount: item.discount,
          unit: item.unit,
        );
      });
    } else {
      setState(() {
        cart.add(SaleItem(
          productId: p.id,
          productName: p.name,
          sku: p.sku,
          unitPrice: p.sellingPrice,
          quantity: 1,
          unit: p.unit,
        ));
      });
    }
  }

  Future<bool> _ensureShiftForSales() async {
    if (AuthService.currentRole != 'sales') return true;
    final uid = AuthService.currentUser?.id ?? '';
    await ShiftStorage.autoCloseStaleShifts();
    final open = await ShiftStorage.currentOpenShift(userId: uid);
    if (open != null) return true;
    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Shift required'),
        content: const Text(
          'Open your shift first before adding sales.\n'
          'Shifts → Open shift.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _promptQty(Product p) async {
    if (!await _ensureShiftForSales()) return;
    final avail = _avail(p);
    final ctrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(p.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: ${avail.toStringAsFixed(0)} ${p.unit}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Enter quantity',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final qty = double.tryParse(ctrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _toast('Enter a valid quantity');
      return;
    }
    if (qty > avail) {
      _toast('Only $avail ${p.unit} in stock');
      return;
    }
    final idx = cart.indexWhere((c) => c.productId == p.id);
    if (idx >= 0) {
      final item = cart[idx];
      final newQ = item.quantity + qty;
      if (newQ > avail) {
        _toast('Only $avail ${p.unit} in stock');
        return;
      }
      setState(() {
        cart[idx] = SaleItem(
          productId: item.productId,
          productName: item.productName,
          sku: item.sku,
          unitPrice: item.unitPrice,
          quantity: newQ,
          discount: item.discount,
          unit: item.unit,
        );
      });
    } else {
      setState(() {
        cart.add(SaleItem(
          productId: p.id,
          productName: p.name,
          sku: p.sku,
          unitPrice: p.sellingPrice,
          quantity: qty,
          unit: p.unit,
        ));
      });
    }
  }

    void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> checkout() async {
    if (cart.isEmpty) {
      _toast('Cart is empty');
      return;
    }

    final discountCtrl = TextEditingController(text: '0');
    final cashCtrl = TextEditingController(text: total.toStringAsFixed(0));
    final transferCtrl = TextEditingController(text: '0');
    final posCtrl = TextEditingController(text: '0');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final cartDisc = double.tryParse(discountCtrl.text) ?? 0;
            final payTotal = (total - cartDisc).clamp(0, double.infinity);
            final cash = double.tryParse(cashCtrl.text) ?? 0;
            final transfer = double.tryParse(transferCtrl.text) ?? 0;
            final pos = double.tryParse(posCtrl.text) ?? 0;
            final tendered = cash + transfer + pos;
            final remaining = payTotal - tendered;

            void balanceToCash() {
              final cDisc = double.tryParse(discountCtrl.text) ?? 0;
              final due = (total - cDisc).clamp(0, double.infinity);
              final t = double.tryParse(transferCtrl.text) ?? 0;
              final p = double.tryParse(posCtrl.text) ?? 0;
              cashCtrl.text = (due - t - p).clamp(0, double.infinity).toStringAsFixed(0);
              setModal(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const Text(
                        'Complete payment',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cart ${money.format(total)} — split across Cash, Transfer, POS if needed',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Discount (₦)',
                          prefixIcon: const Icon(Icons.discount_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) {
                          balanceToCash();
                          setModal(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Amount due',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              money.format(payTotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Payment split',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cashCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Cash (₦)',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          filled: true,
                          fillColor: const Color(0xFFECFDF5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: transferCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Transfer (₦)',
                          prefixIcon: const Icon(Icons.account_balance_outlined),
                          filled: true,
                          fillColor: const Color(0xFFEFF6FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: posCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'POS (₦)',
                          prefixIcon: const Icon(Icons.credit_card_rounded),
                          filled: true,
                          fillColor: const Color(0xFFFFF7ED),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setModal(() {}),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        remaining.abs() < 0.5
                            ? 'Payment complete'
                            : remaining > 0
                                ? 'Still short ${money.format(remaining)}'
                                : 'Change / over ${money.format(-remaining)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: remaining.abs() < 0.5
                              ? AppColors.success
                              : remaining > 0
                                  ? AppColors.danger
                                  : AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            final maxPct = Permissions.maxSelfDiscountPercent(
                              AuthService.currentRole,
                            );
                            if (cartDisc > 0 && total > 0) {
                              final pct = (cartDisc / total) * 100;
                              if (pct > maxPct + 0.01) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Max discount for your role is ${maxPct.toStringAsFixed(0)}%',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                            if (tendered + 0.5 < payTotal) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Payment short by ${money.format(payTotal - tendered)}',
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'CONFIRM PAYMENT',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final cartDisc = double.tryParse(discountCtrl.text) ?? 0;
    final cash = double.tryParse(cashCtrl.text) ?? 0;
    final transfer = double.tryParse(transferCtrl.text) ?? 0;
    final pos = double.tryParse(posCtrl.text) ?? 0;
    final paid = cash + transfer + pos;

    String method;
    final parts = <String>[];
    if (cash > 0) parts.add('Cash');
    if (transfer > 0) parts.add('Transfer');
    if (pos > 0) parts.add('POS');
    if (parts.length > 1) {
      method = 'Mixed';
    } else if (parts.length == 1) {
      method = parts.first;
    } else {
      method = 'Cash';
    }

    setState(() => checkingOut = true);
    try {
      final items = List<SaleItem>.from(cart);
      if (cartDisc > 0 && items.isNotEmpty) {
        final first = items[0];
        items[0] = SaleItem(
          productId: first.productId,
          productName: first.productName,
          sku: first.sku,
          unitPrice: first.unitPrice,
          quantity: first.quantity,
          discount: first.discount + cartDisc,
          unit: first.unit,
        );
      }

      final sale = await SaleStorage.completeSale(
        items: items,
        amountPaid: paid,
        paymentMethod: method,
        cashPaid: cash,
        transferPaid: transfer,
        posPaid: pos,
      );

      if (!mounted) return;
      setState(() {
        cart.clear();
        checkingOut = false;
      });
      await load();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SaleReceiptScreen(sale: sale)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => checkingOut = false);
      _toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
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
                        'Point of Sale',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sales history',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SalesHistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      onPressed: load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  'Tap product → enter qty · Long-press +1 · ${AuthService.currentName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Search products…',
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

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text('No products in stock'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return _productTile(p);
                        },
                      ),
          ),

          // Cart bar
          if (cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cart.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final item = cart[i];
                        return Chip(
                          label: Text(
                            '${item.productName} ×${item.quantity.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => cart.removeAt(i)),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${cart.length} item(s)',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              money.format(total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: checkingOut ? null : checkout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: checkingOut
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'CHARGE',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _productTile(Product p) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _promptQty(p),
        onLongPress: () => addToCart(p),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              Text(
                money.format(p.sellingPrice),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
              Text(
                '${_avail(p).toStringAsFixed(0)} ${p.unit} left',
                style: TextStyle(
                  color: _avail(p) <= p.reorderLevel
                      ? AppColors.danger
                      : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
