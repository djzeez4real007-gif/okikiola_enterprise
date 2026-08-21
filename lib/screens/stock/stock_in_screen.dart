import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../models/stock_in.dart';
import '../../services/auth_service.dart';
import '../../services/product_storage.dart';
import '../../services/location_service.dart';
import '../../services/stock_in_storage.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({super.key});

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  bool loading = true;
  List<StockInRecord> history = [];
  String query = '';
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  bool get canRun =>
      Permissions.canAdjustStock(AuthService.currentRole) ||
      AuthService.currentRole == 'owner' ||
      AuthService.currentRole == 'manager' ||
      AuthService.currentRole == 'storekeeper';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final list = await StockInStorage.getAll();
    if (!mounted) return;
    setState(() {
      history = list;
      loading = false;
    });
  }

  List<StockInRecord> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return history;
    return history.where((r) {
      final blob =
          '${r.supplier} ${r.reference} ${r.reason} ${r.receivedByName} ${r.note}'
              .toLowerCase();
      if (blob.contains(q)) return true;
      return r.lines.any((l) =>
          l.productName.toLowerCase().contains(q) ||
          l.sku.toLowerCase().contains(q));
    }).toList();
  }

  String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy · HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Future<void> openReceive() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReceiveStockScreen()),
    );
    if (ok == true) load();
  }

  void openDetail(StockInRecord r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockInDetailScreen(record: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canRun) {
      return const Scaffold(
        body: Center(child: Text('No permission to receive stock')),
      );
    }

    final list = filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openReceive,
        icon: const Icon(Icons.move_to_inbox_rounded),
        label: const Text('Receive stock'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock in',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Receive purchases and deliveries. Every increase is audited.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search supplier, product, reference…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Receipt history',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (list.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          query.isEmpty
                              ? 'No stock received yet'
                              : 'No match for “$query”',
                        ),
                      ),
                    )
                  else
                    ...list.map((r) {
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => openDetail(r),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.move_to_inbox_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.supplier.isEmpty
                                            ? r.reason
                                            : r.supplier,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${_fmt(r.receivedAt)} · ${r.lines.length} item(s)'
                                        '${r.reference.isNotEmpty ? ' · ${r.reference}' : ''}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  money.format(r.totalCost),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  final supplierCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String reason = 'Purchase';
  bool updateCost = false;
  bool saving = false;

  List<Product> products = [];
  final List<_LineDraft> lines = [];
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    ProductStorage.getAll().then((list) {
      if (!mounted) return;
      setState(() => products = list.where((p) => p.active).toList());
    });
  }

  @override
  void dispose() {
    supplierCtrl.dispose();
    refCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  double get total => lines.fold(0, (s, l) => s + l.qty * l.cost);

  Future<void> addLine() async {
    await _refreshProducts();
    if (products.isEmpty) {
      final created = await _quickCreateProduct();
      if (created == null) return;
      await _refreshProducts();
    }

    Product? selected = products.isNotEmpty ? products.first : null;
    String search = '';
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(
      text: selected != null ? selected.costPrice.toStringAsFixed(0) : '0',
    );

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final filtered = products.where((p) {
              final q = search.trim().toLowerCase();
              if (q.isEmpty) return true;
              return p.name.toLowerCase().contains(q) ||
                  p.sku.toLowerCase().contains(q);
            }).toList();
            if (selected != null && !filtered.contains(selected)) {
              selected = filtered.isNotEmpty ? filtered.first : null;
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Add product',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setModal(() => search = v),
                        decoration: const InputDecoration(
                          labelText: 'Search product',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final created = await _quickCreateProduct();
                            if (created == null) return;
                            await _refreshProducts();
                            setModal(() {
                              selected = created;
                              costCtrl.text =
                                  created.costPrice.toStringAsFixed(0);
                              search = '';
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add new product'),
                        ),
                      ),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No products match'),
                        )
                      else
                        DropdownButtonFormField<Product>(
                          value: selected != null && filtered.contains(selected)
                              ? selected
                              : (filtered.isNotEmpty ? filtered.first : null),
                          decoration: const InputDecoration(labelText: 'Product'),
                          items: filtered
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    '${p.name} (${LocationService.currentId != null ? LocationService.getStockCurrent(p.id) : p.quantity} ${p.unit})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (p) {
                            if (p == null) return;
                            setModal(() {
                              selected = p;
                              costCtrl.text = p.costPrice.toStringAsFixed(0);
                            });
                          },
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Quantity received *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Unit cost (₦)',
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
                        child: const Text(
                          'ADD',
                          style: TextStyle(fontWeight: FontWeight.w900),
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

    if (ok != true || selected == null) return;
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final cost = double.tryParse(costCtrl.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }
    setState(() {
      lines.add(_LineDraft(product: selected!, qty: qty, cost: cost));
    });
  }

  Future<void> _refreshProducts() async {
    final list = await ProductStorage.getAll();
    if (!mounted) return;
    setState(() => products = list.where((p) => p.active).toList());
  }

  Future<Product?> _quickCreateProduct() async {
    final nameCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '0');
    final catCtrl = TextEditingController(text: 'General');
    String unit = 'pcs';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
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
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_box_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'New product\nAdded to catalogue for all locations',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Product name *',
                          prefixIcon: const Icon(Icons.label_outline),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: catCtrl,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: const Icon(Icons.category_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: unit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          'pcs',
                          'carton',
                          'pack',
                          'bag',
                          'yard',
                          'kg',
                          'litre',
                        ]
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModal(() => unit = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Cost price (₦)',
                          prefixIcon: const Icon(Icons.money_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: sellCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Selling price (₦) *',
                          prefixIcon: const Icon(Icons.sell_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty ||
                                (double.tryParse(sellCtrl.text) ?? 0) <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Name and selling price required'),
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
                            'CREATE PRODUCT',
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

    if (ok != true || nameCtrl.text.trim().isEmpty) return null;
    final sell = double.tryParse(sellCtrl.text) ?? 0;
    final cost = double.tryParse(costCtrl.text) ?? 0;
    if (sell <= 0) return null;
    final sku = await ProductStorage.nextSku();
    return ProductStorage.create(
      name: nameCtrl.text,
      sku: sku,
      category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
      unit: unit,
      costPrice: cost,
      sellingPrice: sell,
      quantity: 0,
      reorderLevel: 5,
    );
  }

  Future<void> save() async {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final stockLines = lines
          .map(
            (l) => StockInLine(
              productId: l.product.id,
              productName: l.product.name,
              sku: l.product.sku,
              unit: l.product.unit,
              quantity: l.qty,
              unitCost: l.cost,
              previousQty: l.product.quantity,
            ),
          )
          .toList();
      await StockInStorage.receive(
        supplier: supplierCtrl.text,
        reference: refCtrl.text,
        reason: reason,
        lines: stockLines,
        note: noteCtrl.text,
        updateCostPrice: updateCost,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock received'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('Receive stock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                TextField(
                  controller: supplierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supplier (optional)',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invoice / delivery note',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: StockInRecord.reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => reason = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Update product cost price',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Use unit cost on this receipt as new cost',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: updateCost,
                  activeThumbColor: AppColors.primary,
                  onChanged: AuthService.currentRole == 'owner' ||
                          AuthService.currentRole == 'manager'
                      ? (v) => setState(() => updateCost = v)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              TextButton.icon(
                onPressed: addLine,
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
            ],
          ),
          if (lines.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('No products added yet')),
            )
          else
            ...lines.asMap().entries.map((e) {
              final i = e.key;
              final l = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '+${l.qty} ${l.product.unit} @ ${money.format(l.cost)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money.format(l.qty * l.cost),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      onPressed: () => setState(() => lines.removeAt(i)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          Text(
            'Total cost: ${money.format(total)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: saving ? null : save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                saving ? 'Saving…' : 'CONFIRM RECEIVE',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineDraft {
  final Product product;
  final double qty;
  final double cost;

  _LineDraft({
    required this.product,
    required this.qty,
    required this.cost,
  });
}

class StockInDetailScreen extends StatelessWidget {
  final StockInRecord record;

  const StockInDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    String when;
    try {
      when = DateFormat('dd MMM yyyy · HH:mm')
          .format(DateTime.parse(record.receivedAt));
    } catch (_) {
      when = record.receivedAt;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('Stock in detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.supplier.isEmpty ? record.reason : record.supplier,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '$when · ${record.receivedByName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (record.reference.isNotEmpty)
                  Text(
                    'Ref: ${record.reference}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  money.format(record.totalCost),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...record.lines.map((l) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.productName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${l.sku} · ${l.previousQty} → ${l.newQty} ${l.unit}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${l.quantity} @ ${money.format(l.unitCost)} = ${money.format(l.lineCost)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (record.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${record.note}'),
          ],
        ],
      ),
    );
  }
}
