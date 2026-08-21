import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/product_storage.dart';
import '../../services/location_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final int? index;

  const ProductFormScreen({super.key, this.product, this.index});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final skuCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final sellCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final reorderCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  String unit = 'pcs';
  bool saving = false;

  bool get isEdit => widget.product != null;
  bool get canEditCost =>
      Permissions.canEditCostPrice(AuthService.currentRole);

  static const _baseUnits = [
    'pcs',
    'carton',
    'pack',
    'yard',
    'sheet',
    'pan',
    'gallon',
    'kg',
    'g',
    'litre',
    'bag',
    'dozen',
  ];

  List<String> get _unitChoices {
    final u = _normalizeUnit(unit);
    if (_baseUnits.contains(u)) return List<String>.from(_baseUnits);
    return [..._baseUnits, u];
  }

  String _normalizeUnit(String raw) {
    final s = raw.trim().toLowerCase();
    const map = {
      'bags': 'bag',
      'bag': 'bag',
      'pcs': 'pcs',
      'pc': 'pcs',
      'piece': 'pcs',
      'pieces': 'pcs',
      'cartons': 'carton',
      'carton': 'carton',
      'packs': 'pack',
      'pack': 'pack',
      'yards': 'yard',
      'yard': 'yard',
      'sheets': 'sheet',
      'sheet': 'sheet',
      'pans': 'pan',
      'pan': 'pan',
      'gallons': 'gallon',
      'gallon': 'gallon',
      'kgs': 'kg',
      'kg': 'kg',
      'kilogram': 'kg',
      'kilograms': 'kg',
      'grams': 'g',
      'gram': 'g',
      'g': 'g',
      'litre': 'litre',
      'liter': 'litre',
      'litres': 'litre',
      'liters': 'litre',
      'l': 'litre',
      'dozen': 'dozen',
      'dozens': 'dozen',
    };
    return map[s] ?? (s.isEmpty ? 'pcs' : s);
  }


  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final p = widget.product!;
      nameCtrl.text = p.name;
      skuCtrl.text = p.sku;
      categoryCtrl.text = p.category;
      costCtrl.text = p.costPrice.toString();
      sellCtrl.text = p.sellingPrice.toString();
      final q = LocationService.currentId != null
          ? LocationService.getStockCurrent(p.id)
          : p.quantity;
      qtyCtrl.text = q.toString();
      reorderCtrl.text = p.reorderLevel.toString();
      descCtrl.text = p.description;
      unit = _normalizeUnit(p.unit);
    } else {
      ProductStorage.nextSku().then((s) {
        if (mounted) setState(() => skuCtrl.text = s);
      });
      reorderCtrl.text = '5';
      qtyCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    skuCtrl.dispose();
    categoryCtrl.dispose();
    costCtrl.dispose();
    sellCtrl.dispose();
    qtyCtrl.dispose();
    reorderCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  double _parse(String v) => double.tryParse(v.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      if (isEdit) {
        final old = widget.product!;
        final updated = old.copyWith(
          name: nameCtrl.text.trim(),
          sku: skuCtrl.text.trim().toUpperCase(),
          category: categoryCtrl.text.trim(),
          unit: _normalizeUnit(unit),
          costPrice: canEditCost ? _parse(costCtrl.text) : old.costPrice,
          sellingPrice: _parse(sellCtrl.text),
          quantity: _parse(qtyCtrl.text),
          reorderLevel: _parse(reorderCtrl.text),
          description: descCtrl.text.trim(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await ProductStorage.update(widget.index!, updated);
        final locId = LocationService.currentId;
        if (locId != null) {
          await LocationService.setStock(
            locId,
            updated.id,
            _parse(qtyCtrl.text),
            reason: 'Product form qty at location',
          );
        }
      } else {
        await ProductStorage.create(
          name: nameCtrl.text,
          sku: skuCtrl.text,
          category: categoryCtrl.text,
          unit: _normalizeUnit(unit),
          costPrice: _parse(costCtrl.text),
          sellingPrice: _parse(sellCtrl.text),
          quantity: _parse(qtyCtrl.text),
          reorderLevel: _parse(reorderCtrl.text),
          description: descCtrl.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Product updated' : 'Product added'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit product' : 'New product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Product details\nSKU, prices and stock',
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
            _card([
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product name *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: skuCtrl,
                decoration: const InputDecoration(
                  labelText: 'SKU / Code *',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  hintText: 'e.g. Beverages, Provisions',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unitChoices.contains(unit) ? unit : _normalizeUnit(unit),
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                items: _unitChoices
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => unit = v);
                },
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              if (canEditCost)
                TextFormField(
                  controller: costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Cost price (₦) *',
                    prefixIcon: Icon(Icons.money_outlined),
                    helperText: 'Only owner can see/edit cost price',
                  ),
                  validator: (v) {
                    if (!canEditCost) return null;
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
              if (canEditCost) const SizedBox(height: 12),
              TextFormField(
                controller: sellCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Selling price (₦) *',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Quantity in stock *',
                  prefixIcon: Icon(Icons.inventory_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reorderCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Reorder level (low stock alert)',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              TextFormField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  isEdit ? 'UPDATE PRODUCT' : 'SAVE PRODUCT',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }
}
