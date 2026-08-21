import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sale.dart';

class ReceiptPdfService {
  static final _money = NumberFormat.currency(symbol: 'NGN ', decimalDigits: 2);
  static final _moneyShort =
      NumberFormat.currency(symbol: 'N', decimalDigits: 0);

  static Future<void> share(Sale sale) async {
    final doc = await _build(sale);
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'receipt_${sale.receiptNo}.pdf',
    );
  }

  static Future<void> print(Sale sale) async {
    final doc = await _build(sale);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'Receipt ${sale.receiptNo}',
    );
  }

  static Future<pw.Document> _build(Sale sale) async {
    final doc = pw.Document();
    final when = _fmt(sale.createdAt);
    final teal = PdfColor.fromHex('#0F766E');
    final dark = PdfColor.fromHex('#0F172A');
    final muted = PdfColor.fromHex('#64748B');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Container(
                  width: 48,
                  height: 48,
                  decoration: pw.BoxDecoration(
                    color: teal,
                    borderRadius: pw.BorderRadius.circular(24),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'OE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'OKIKIOLA ENTERPRISE',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: dark,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'NIG LTD',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: muted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'WhatsApp 07068791117',
                  style: pw.TextStyle(fontSize: 9, color: muted),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: teal, thickness: 1.5),
              pw.SizedBox(height: 8),
              _row('Receipt', sale.receiptNo, dark, muted),
              _row('Date', when, dark, muted),
              _row('Cashier', sale.soldByName, dark, muted),
              if (sale.voided)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(
                    '*** VOIDED ***',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: PdfColors.red,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              ...sale.items.map((it) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        it.productName,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: dark,
                        ),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${_qty(it.quantity)} ${it.unit} x ${_moneyShort.format(it.unitPrice)}',
                            style: pw.TextStyle(fontSize: 9, color: muted),
                          ),
                          pw.Text(
                            _moneyShort.format(it.lineTotal),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: dark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              _row('Subtotal', _moneyShort.format(sale.subtotal), dark, muted),
              if (sale.discountTotal > 0)
                _row('Discount', '- ${_moneyShort.format(sale.discountTotal)}',
                    dark, muted),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#ECFDF5'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: teal,
                      ),
                    ),
                    pw.Text(
                      _moneyShort.format(sale.total),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: teal,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Payment: ${sale.paymentMethod}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: dark,
                ),
              ),
              if (sale.cashPaid > 0)
                _row('Cash', _moneyShort.format(sale.cashPaid), dark, muted),
              if (sale.transferPaid > 0)
                _row(
                    'Transfer', _moneyShort.format(sale.transferPaid), dark, muted),
              if (sale.posPaid > 0)
                _row('POS', _moneyShort.format(sale.posPaid), dark, muted),
              if (sale.note.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Note: ${sale.note}',
                    style: pw.TextStyle(fontSize: 9, color: muted)),
              ],
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Thank you for your patronage',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: teal,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Goods sold are not returnable except where defective',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, color: muted),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _row(
      String k, String v, PdfColor dark, PdfColor muted) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: pw.TextStyle(fontSize: 9, color: muted)),
          pw.Text(v,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark)),
        ],
      ),
    );
  }

  static String _qty(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);

  static String _fmt(String iso) {
    try {
      return DateFormat('dd MMM yyyy  HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
