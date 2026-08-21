import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/sale.dart';
import '../../services/location_service.dart';

class SaleReceiptScreen extends StatelessWidget {
  final Sale sale;

  const SaleReceiptScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    String when;
    try {
      when = DateFormat('dd MMM yyyy · HH:mm')
          .format(DateTime.parse(sale.createdAt));
    } catch (_) {
      when = sale.createdAt;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Sale receipt'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'OKIKIOLA ENTERPRISE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Text(
                        'NIG LTD',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((LocationService.current?.name ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          LocationService.current!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if ((LocationService.current?.address ?? '').isNotEmpty)
                        Text(
                          LocationService.current!.address,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      if ((LocationService.current?.phone ?? '').isNotEmpty)
                        Text(
                          LocationService.current!.phone,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          sale.receiptNo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(
                        money.format(sale.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(when,
                          style: TextStyle(color: Colors.grey.shade600)),
                      const Divider(height: 28),
                      ...sale.items.map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${i.productName} ×${i.quantity.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  money.format(i.lineTotal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 24),
                      _row('Subtotal', money.format(sale.subtotal)),
                      if (sale.discountTotal > 0)
                        _row('Discount', '-${money.format(sale.discountTotal)}'),
                      _row('Total', money.format(sale.total), bold: true),
                      if (sale.cashPaid > 0)
                        _row('Cash', money.format(sale.cashPaid)),
                      if (sale.transferPaid > 0)
                        _row('Transfer', money.format(sale.transferPaid)),
                      if (sale.posPaid > 0)
                        _row('POS', money.format(sale.posPaid)),
                      _row(
                        'Paid (${sale.paymentMethod})',
                        money.format(sale.amountPaid),
                        bold: true,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Served by ${sale.soldByName}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'WhatsApp 07068791117',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(a)),
          Text(
            b,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
