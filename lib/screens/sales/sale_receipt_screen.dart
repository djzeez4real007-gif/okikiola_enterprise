import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/sale.dart';
import '../../services/receipt_pdf_service.dart';

class SaleReceiptScreen extends StatelessWidget {
  final Sale sale;

  const SaleReceiptScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    String when;
    try {
      when = DateFormat('dd MMM yyyy · HH:mm').format(DateTime.parse(sale.createdAt));
    } catch (_) {
      when = sale.createdAt;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            tooltip: 'Print',
            onPressed: () async {
              try {
                await ReceiptPdfService.print(sale);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.print_rounded),
          ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: () async {
              try {
                await ReceiptPdfService.share(sale);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    ),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                const Text(
                  'OKIKIOLA ENTERPRISE',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  'NIG LTD',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'WhatsApp 07068791117',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(height: 2, color: AppColors.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                _meta('Receipt', sale.receiptNo),
                _meta('Date', when),
                _meta('Cashier', sale.soldByName),
                if (sale.voided)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'VOIDED',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(),
                ...sale.items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.productName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${it.quantity} ${it.unit} × ${money.format(it.unitPrice)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money.format(it.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                _meta('Subtotal', money.format(sale.subtotal)),
                if (sale.discountTotal > 0)
                  _meta('Discount', '- ${money.format(sale.discountTotal)}'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        money.format(sale.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Payment: ${sale.paymentMethod}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (sale.cashPaid > 0)
                  _meta('Cash', money.format(sale.cashPaid)),
                if (sale.transferPaid > 0)
                  _meta('Transfer', money.format(sale.transferPaid)),
                if (sale.posPaid > 0) _meta('POS', money.format(sale.posPaid)),
                const SizedBox(height: 16),
                Text(
                  'Thank you for your patronage',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ReceiptPdfService.print(sale);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await ReceiptPdfService.share(sale);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _meta(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
