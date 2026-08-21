import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/stock_snapshot.dart';
import '../../services/stock_snapshot_storage.dart';

class StockSnapshotsScreen extends StatefulWidget {
  const StockSnapshotsScreen({super.key});

  @override
  State<StockSnapshotsScreen> createState() => _StockSnapshotsScreenState();
}

class _StockSnapshotsScreenState extends State<StockSnapshotsScreen> {
  bool loading = true;
  bool capturing = false;
  List<StockSnapshot> snaps = [];
  String query = '';
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final list = await StockSnapshotStorage.getAll();
    if (!mounted) return;
    setState(() {
      snaps = list;
      loading = false;
    });
  }

  Future<void> takeNow() async {
    setState(() => capturing = true);
    try {
      await StockSnapshotStorage.capture(source: 'manual');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Today\'s stock snapshot saved'),
          backgroundColor: AppColors.success,
        ),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  List<StockSnapshot> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return snaps;
    return snaps
        .where((s) =>
            s.dateKey.contains(q) ||
            s.takenByName.toLowerCase().contains(q) ||
            s.source.toLowerCase().contains(q))
        .toList();
  }

  String _fmtWhen(String iso) {
    try {
      return DateFormat('dd MMM yyyy · HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  void openDetail(StockSnapshot s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SnapshotDetailScreen(snapshot: s)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: capturing ? null : takeNow,
        icon: capturing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.camera_alt_outlined),
        label: Text(capturing ? 'Saving…' : 'Snapshot now'),
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
                          'Daily stock snapshots',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Frozen inventory for each day. Auto-saved when a shift closes '
                          'or a stock count completes. Use Reports to view stock as of a date.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search by date, person, source…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (list.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('No snapshots yet — take one or close a shift'),
                      ),
                    )
                  else
                    ...list.map((s) {
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => openDetail(s),
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
                                    Icons.photo_library_outlined,
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
                                        s.dateKey,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        '${_fmtWhen(s.takenAt)} · ${s.source} · ${s.takenByName}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${s.productCount} items · ${s.lowStockCount} low',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  money.format(s.totalValue),
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

class SnapshotDetailScreen extends StatefulWidget {
  final StockSnapshot snapshot;

  const SnapshotDetailScreen({super.key, required this.snapshot});

  @override
  State<SnapshotDetailScreen> createState() => _SnapshotDetailScreenState();
}

class _SnapshotDetailScreenState extends State<SnapshotDetailScreen> {
  String query = '';
  bool lowOnly = false;
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  List<StockSnapshotLine> get lines {
    var list = widget.snapshot.lines;
    if (lowOnly) list = list.where((l) => l.isLowStock).toList();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((l) =>
            l.productName.toLowerCase().contains(q) ||
            l.sku.toLowerCase().contains(q) ||
            l.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final list = lines;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text('Stock · ${s.dateKey}')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary,
            child: Text(
              'Value ${money.format(s.totalValue)} · ${s.productCount} products · '
              '${s.lowStockCount} low stock',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: !lowOnly,
                  onSelected: (_) => setState(() => lowOnly = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Low stock only'),
                  selected: lowOnly,
                  onSelected: (_) => setState(() => lowOnly = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final l = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.productName,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${l.sku} · ${l.quantity} ${l.unit}'
                              '${l.isLowStock ? ' · LOW' : ''}',
                              style: TextStyle(
                                color: l.isLowStock
                                    ? AppColors.danger
                                    : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: l.isLowStock
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        money.format(l.stockValue),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
