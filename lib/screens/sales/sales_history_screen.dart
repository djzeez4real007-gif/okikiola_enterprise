import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sale.dart';
import '../../services/auth_service.dart';
import '../../services/sale_storage.dart';
import 'sale_receipt_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  bool loading = true;
  List<Sale> sales = [];
  String query = '';
  final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final list = await SaleStorage.getAll();
    if (!mounted) return;
    setState(() {
      sales = list;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canVoid = Permissions.canVoidSale(AuthService.currentRole);
    final filtered = sales.where((s) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return true;
      final items = s.items.map((e) => e.productName).join(' ').toLowerCase();
      final blob =
          '${s.receiptNo} ${s.soldByName} ${s.paymentMethod} $items'.toLowerCase();
      return blob.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Sales history')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search receipt, product, staff…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
              ? Center(child: Text(sales.isEmpty ? 'No sales yet' : 'No match'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    String when;
                    try {
                      when = DateFormat('dd MMM · HH:mm')
                          .format(DateTime.parse(s.createdAt));
                    } catch (_) {
                      when = s.createdAt;
                    }
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.voided
                              ? Colors.grey.shade300
                              : AppColors.primary.withValues(alpha: 0.15),
                          child: Icon(
                            s.voided
                                ? Icons.block
                                : Icons.receipt_long_rounded,
                            color: s.voided
                                ? Colors.grey
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          s.receiptNo,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            decoration:
                                s.voided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '$when · ${s.soldByName} · ${s.paymentMethod}',
                        ),
                        trailing: Text(
                          money.format(s.total),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: s.voided
                                ? Colors.grey
                                : AppColors.primary,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SaleReceiptScreen(sale: s),
                            ),
                          );
                        },
                        onLongPress: !canVoid || s.voided
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Void sale?'),
                                    content: Text(
                                      'Void ${s.receiptNo} and restock items?\nOnly owner/manager can void.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Void'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await SaleStorage.voidSale(s);
                                  load();
                                }
                              },
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
