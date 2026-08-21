import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/stock_count.dart';
import '../../services/auth_service.dart';
import '../../services/stock_count_storage.dart';

class StockCountScreen extends StatefulWidget {
  const StockCountScreen({super.key});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  bool loading = true;
  StockCountSession? draft;
  List<StockCountSession> history = [];
  String homeQuery = '';
  String draftQuery = '';
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  final Map<String, TextEditingController> _ctrls = {};

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

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final d = await StockCountStorage.openDraft();
    final all = await StockCountStorage.getAll();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    if (d != null) {
      for (final line in d.lines) {
        _ctrls[line.productId] = TextEditingController(
          text: line.countedQty == line.countedQty.roundToDouble()
              ? line.countedQty.toStringAsFixed(0)
              : line.countedQty.toString(),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      draft = d;
      history = all.where((s) => s.status == 'completed').toList();
      loading = false;
    });
  }

  Future<void> startCount() async {
    try {
      await StockCountStorage.startNew();
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  StockCountSession _sessionFromInputs() {
    final d = draft!;
    final lines = d.lines.map((l) {
      final raw = _ctrls[l.productId]?.text ?? '${l.countedQty}';
      final counted = double.tryParse(raw) ?? l.systemQty;
      return StockCountLine(
        productId: l.productId,
        productName: l.productName,
        sku: l.sku,
        unit: l.unit,
        systemQty: l.systemQty,
        countedQty: counted,
        costPrice: l.costPrice,
      );
    }).toList();
    return StockCountSession(
      id: d.id,
      status: d.status,
      startedAt: d.startedAt,
      startedById: d.startedById,
      startedByName: d.startedByName,
      lines: lines,
      note: d.note,
    );
  }

  Future<void> saveDraftOnly() async {
    final session = _sessionFromInputs();
    await StockCountStorage.saveDraft(session);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft saved'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> completeCount() async {
    final session = _sessionFromInputs();
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Complete stock count'),
        content: Text(
          'Variances: ${session.varianceLines}\n'
          'Shrinkage (missing): ${money.format(session.totalShrinkValue)}\n'
          'Over: ${money.format(session.totalOverValue)}\n\n'
          'Update product quantities to counted amounts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Save report only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update stock'),
          ),
        ],
      ),
    );
    if (apply == null) return;
    await StockCountStorage.complete(
      session: session,
      applyAdjustments: apply,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stock count completed'),
        backgroundColor: AppColors.success,
      ),
    );
    await load();
  }

  String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy · HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  void _openDetail(StockCountSession s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockCountDetailScreen(session: s),
      ),
    );
  }

  List<StockCountSession> get filteredHistory {
    final q = homeQuery.trim().toLowerCase();
    if (q.isEmpty) return history;
    return history.where((s) {
      final blob =
          '${s.startedByName} ${s.note} ${_fmt(s.completedAt ?? s.startedAt)}'
              .toLowerCase();
      if (blob.contains(q)) return true;
      return s.lines.any((l) =>
          l.productName.toLowerCase().contains(q) ||
          l.sku.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!canRun) {
      return const Scaffold(
        body: Center(
          child: Text('Only owner / manager / storekeeper can run stock count'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : draft != null
              ? _buildDraft()
              : _buildHome(),
    );
  }

  Widget _buildHome() {
    final list = filteredHistory;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                  'Stock count',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Count physical stock and compare with system. '
                  'Shortages show as shrinkage.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: startCount,
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text(
                      'START NEW COUNT',
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => homeQuery = v),
            decoration: InputDecoration(
              hintText: 'Search past counts, products, staff…',
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
            'Past counts',
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
                  homeQuery.isEmpty
                      ? 'No completed counts yet'
                      : 'No match for “$homeQuery”',
                ),
              ),
            )
          else
            ...list.map((s) {
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openDetail(s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _fmt(s.completedAt ?? s.startedAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.startedByName} · ${s.varianceLines} variance(s)',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip(
                              'Shrink ${money.format(s.totalShrinkValue)}',
                              AppColors.danger,
                            ),
                            _chip(
                              'Over ${money.format(s.totalOverValue)}',
                              AppColors.accent,
                            ),
                            if (s.appliedToStock)
                              _chip('Stock updated', AppColors.success),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to view line variances',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11),
        ),
      );

  Widget _buildDraft() {
    final session = _sessionFromInputs();
    final q = draftQuery.trim().toLowerCase();
    final lines = draft!.lines.where((l) {
      if (q.isEmpty) return true;
      return l.productName.toLowerCase().contains(q) ||
          l.sku.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Counting now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                'System vs physical · edit Counted column',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniStat('Items', '${draft!.lines.length}'),
                  const SizedBox(width: 8),
                  _miniStat('Variance', '${session.varianceLines}'),
                  const SizedBox(width: 8),
                  _miniStat(
                    'Shrink',
                    money.format(session.totalShrinkValue),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() => draftQuery = v),
            decoration: InputDecoration(
              hintText: 'Search product or SKU…',
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
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final line = lines[i];
              final ctrl = _ctrls[line.productId]!;
              final counted = double.tryParse(ctrl.text) ?? line.systemQty;
              final variance = counted - line.systemQty;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: variance.abs() > 0.0001
                      ? Border.all(
                          color: variance < 0
                              ? AppColors.danger.withValues(alpha: 0.4)
                              : AppColors.accent.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${line.sku} · System: ${line.systemQty} ${line.unit}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Counted',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 90,
                          child: Text(
                            variance == 0
                                ? 'OK'
                                : variance > 0
                                    ? '+${variance.toStringAsFixed(1)}'
                                    : variance.toStringAsFixed(1),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: variance == 0
                                  ? AppColors.success
                                  : variance < 0
                                      ? AppColors.danger
                                      : AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Discard count?'),
                        content: const Text('Draft will be deleted.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await StockCountStorage.discardDraft(draft!);
                      await load();
                    }
                  },
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: saveDraftOnly,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: completeCount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'COMPLETE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String k, String v) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                v,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                k,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Full variance breakdown for a completed count.
class StockCountDetailScreen extends StatefulWidget {
  final StockCountSession session;

  const StockCountDetailScreen({super.key, required this.session});

  @override
  State<StockCountDetailScreen> createState() => _StockCountDetailScreenState();
}

class _StockCountDetailScreenState extends State<StockCountDetailScreen> {
  String query = '';
  bool onlyVariance = true;
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  List<StockCountLine> get lines {
    var list = widget.session.lines;
    if (onlyVariance) {
      list = list.where((l) => l.hasVariance).toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((l) =>
            l.productName.toLowerCase().contains(q) ||
            l.sku.toLowerCase().contains(q))
        .toList();
  }

  String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy · HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final list = lines;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Count details'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmt(s.completedAt ?? s.startedAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${s.startedByName}'
                  '${s.appliedToStock ? ' · Stock was updated' : ' · Report only'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _headStat('Shrink', money.format(s.totalShrinkValue)),
                    const SizedBox(width: 8),
                    _headStat('Over', money.format(s.totalOverValue)),
                    const SizedBox(width: 8),
                    _headStat('Lines', '${s.varianceLines}'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Search product or SKU…',
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
                  label: const Text('Variances only'),
                  selected: onlyVariance,
                  onSelected: (v) => setState(() => onlyVariance = v),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('All items'),
                  selected: !onlyVariance,
                  onSelected: (v) => setState(() => onlyVariance = !v),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No lines to show'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final l = list[i];
                      final v = l.variance;
                      final color = !l.hasVariance
                          ? AppColors.success
                          : v < 0
                              ? AppColors.danger
                              : AppColors.accent;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${l.sku} · ${l.unit}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _kv('System', _qty(l.systemQty)),
                                _kv('Counted', _qty(l.countedQty)),
                                _kv(
                                  'Diff',
                                  v == 0
                                      ? '0'
                                      : (v > 0
                                          ? '+${_qty(v)}'
                                          : _qty(v)),
                                  color: color,
                                ),
                              ],
                            ),
                            if (l.hasVariance) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Value impact: ${money.format(l.varianceValue.abs())}'
                                '${v < 0 ? ' (shrinkage)' : ' (over)'}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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

  String _qty(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);

  Widget _headStat(String k, String v) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                v,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                k,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _kv(String k, String v, {Color? color}) => Expanded(
        child: Column(
          children: [
            Text(
              k,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            Text(
              v,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color ?? Colors.black87,
              ),
            ),
          ],
        ),
      );
}
