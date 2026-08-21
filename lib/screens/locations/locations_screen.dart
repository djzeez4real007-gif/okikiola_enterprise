import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shop_location.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/product_storage.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<ShopLocation> locations = [];

  bool get isOwner =>
      AuthService.currentRole == 'owner' ||
      AuthService.currentRole == 'manager';

  @override
  void initState() {
    super.initState();
    LocationService.currentListenable.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    LocationService.currentListenable.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() => locations = LocationService.all());

  Future<void> _addOrEdit({ShopLocation? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');

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
                Text(
                  existing == null ? 'New location' : 'Edit location',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
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
                    'SAVE',
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
    try {
      if (existing == null) {
        await LocationService.create(
          name: nameCtrl.text,
          address: addrCtrl.text,
          phone: phoneCtrl.text,
        );
      } else {
        await LocationService.update(ShopLocation(
          id: existing.id,
          name: nameCtrl.text.trim(),
          address: addrCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          active: existing.active,
          isDefault: existing.isDefault,
          createdAt: existing.createdAt,
        ));
      }
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _switch(ShopLocation loc) async {
    try {
      await LocationService.switchTo(loc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${loc.name}'),
          backgroundColor: AppColors.success,
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = LocationService.current;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Add location'),
            )
          : null,
      body: ListView(
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
                  'Locations',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Working at: ${current?.name ?? '—'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Sales, stock in, and counts apply to the selected shop. '
                  'Products catalogue is shared; quantities are per location.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StockTransferScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Transfer stock between locations'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your shops',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...locations.map((loc) {
            final selected = current?.id == loc.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: selected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: selected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                ),
                title: Text(
                  loc.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    if (loc.address.isNotEmpty) loc.address,
                    if (!loc.active) 'Inactive',
                    if (selected) 'Current',
                  ].join(' · '),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'switch') await _switch(loc);
                    if (v == 'edit' && isOwner) await _addOrEdit(existing: loc);
                    if (v == 'toggle' && isOwner) {
                      await LocationService.update(ShopLocation(
                        id: loc.id,
                        name: loc.name,
                        address: loc.address,
                        phone: loc.phone,
                        active: !loc.active,
                        isDefault: loc.isDefault,
                        createdAt: loc.createdAt,
                      ));
                      _refresh();
                    }
                  },
                  itemBuilder: (_) => [
                    if (!selected)
                      const PopupMenuItem(
                        value: 'switch',
                        child: Text('Work at this location'),
                      ),
                    if (isOwner)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                    if (isOwner)
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(loc.active ? 'Deactivate' : 'Activate'),
                      ),
                  ],
                ),
                onTap: selected ? null : () => _switch(loc),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  String? fromId;
  String? toId;
  String? productId;
  String productSearch = '';
  final qtyCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  bool saving = false;
  List products = [];

  @override
  void initState() {
    super.initState();
    final locs = LocationService.all(activeOnly: true);
    fromId = LocationService.currentId ??
        (locs.isNotEmpty ? locs.first.id : null);
    if (locs.length > 1) {
      toId = locs.firstWhere((l) => l.id != fromId, orElse: () => locs.last).id;
    }
    ProductStorage.getAll().then((list) {
      if (mounted) setState(() => products = list.where((p) => p.active).toList());
    });
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (fromId == null || toId == null || productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select locations and product')),
      );
      return;
    }
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final p = products.cast().firstWhere((e) => e.id == productId);
    setState(() => saving = true);
    try {
      await LocationService.transfer(
        productId: p.id,
        productName: p.name,
        fromLocationId: fromId!,
        toLocationId: toId!,
        quantity: qty,
        note: noteCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer completed'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
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
    final locs = LocationService.all(activeOnly: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Stock transfer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: fromId,
            decoration: const InputDecoration(labelText: 'From location'),
            items: locs
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: (v) => setState(() => fromId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: toId,
            decoration: const InputDecoration(labelText: 'To location'),
            items: locs
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: (v) => setState(() => toId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => productSearch = v),
            decoration: const InputDecoration(
              labelText: 'Search product',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: () {
              final q = productSearch.trim().toLowerCase();
              final filtered = products.where((p) {
                if (q.isEmpty) return true;
                return p.name.toLowerCase().contains(q) ||
                    p.sku.toLowerCase().contains(q);
              }).toList();
              if (productId != null &&
                  filtered.any((p) => p.id == productId)) {
                return productId;
              }
              return null;
            }(),
            decoration: const InputDecoration(labelText: 'Product'),
            items: products
                .where((p) {
                  final q = productSearch.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return p.name.toLowerCase().contains(q) ||
                      p.sku.toLowerCase().contains(q);
                })
                .map<DropdownMenuItem<String>>(
                  (p) => DropdownMenuItem(
                    value: p.id as String,
                    child: Text(
                      '${p.name} (${fromId != null ? LocationService.getStock(fromId!, p.id) : 0} avail)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => productId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: saving ? null : submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(
              saving ? 'Transferring…' : 'TRANSFER',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent transfers',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...LocationService.transferHistory().take(20).map((tr) {
            String when;
            try {
              when = DateFormat('dd MMM · HH:mm')
                  .format(DateTime.parse(tr['at'].toString()));
            } catch (_) {
              when = '${tr['at']}';
            }
            String locName(String? id) {
              if (id == null || id.isEmpty) return '?';
              for (final l in LocationService.all()) {
                if (l.id == id) return l.name;
              }
              return id;
            }
            final from = locName(tr['fromLocationId']?.toString());
            final to = locName(tr['toLocationId']?.toString());
            return ListTile(
              dense: true,
              title: Text(
                '${tr['productName']} × ${tr['quantity']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('$from → $to · $when · ${tr['byName']}'),
            );
          }),
        ],
      ),
    );
  }
}
