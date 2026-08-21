import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinancialReportData {
  final String periodLabel;
  final double sales;
  final int salesCount;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final int expenseCount;
  final double cashShort;
  final double netProfit;
  final double unitsSold;
  final List<Map<String, dynamic>> topSellers;
  final String locationName;
  final String generatedBy;

  FinancialReportData({
    required this.periodLabel,
    required this.sales,
    required this.salesCount,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.expenseCount,
    required this.cashShort,
    required this.netProfit,
    required this.unitsSold,
    required this.topSellers,
    required this.locationName,
    required this.generatedBy,
  });
}

class FinancialReportPdfService {
  static final _money = NumberFormat.currency(symbol: 'NGN ', decimalDigits: 2);

  static Future<void> share(FinancialReportData d) async {
    final doc = await _build(d);
    final bytes = await doc.save();
    final safe = d.periodLabel.replaceAll(RegExp(r'[^\w\- ]'), '');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Okikiola_P&L_$safe.pdf',
    );
  }

  static Future<void> print(FinancialReportData d) async {
    final doc = await _build(d);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'P&L ${d.periodLabel}',
    );
  }

  static Future<pw.Document> _build(FinancialReportData d) async {
    final doc = pw.Document();
    final teal = PdfColor.fromHex('#0F766E');
    final dark = PdfColor.fromHex('#0F172A');
    final muted = PdfColor.fromHex('#64748B');
    final now = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    pw.Widget line(String label, String value, {bool bold = false, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? dark,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? dark,
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'OKIKIOLA ENTERPRISE NIG LTD',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                      color: teal,
                    ),
                  ),
                  pw.Text(
                    'Profit & Loss Report',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                      color: dark,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Period: ${d.periodLabel}',
                      style: pw.TextStyle(fontSize: 10, color: muted)),
                  pw.Text('Location: ${d.locationName}',
                      style: pw.TextStyle(fontSize: 10, color: muted)),
                  pw.Text('Generated: $now',
                      style: pw.TextStyle(fontSize: 10, color: muted)),
                  pw.Text('By: ${d.generatedBy}',
                      style: pw.TextStyle(fontSize: 10, color: muted)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: teal, thickness: 2),
          pw.SizedBox(height: 16),

          pw.Text('SUMMARY',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 12, color: teal)),
          pw.SizedBox(height: 8),
          line('Sales revenue (${d.salesCount} receipts)', _money.format(d.sales)),
          line('Cost of goods sold (COGS)', _money.format(d.cogs)),
          line('Gross profit', _money.format(d.grossProfit),
              bold: true, color: teal),
          pw.SizedBox(height: 6),
          line('Operating expenses (${d.expenseCount})',
              _money.format(d.expenses)),
          if (d.cashShort > 0)
            line('Cash shortages (shifts)', _money.format(d.cashShort)),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#ECFDF5'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: line(
              'NET PROFIT',
              _money.format(d.netProfit),
              bold: true,
              color: teal,
            ),
          ),

          pw.SizedBox(height: 12),
          line('Units sold', d.unitsSold.toStringAsFixed(
              d.unitsSold == d.unitsSold.roundToDouble() ? 0 : 1)),
          line(
            'Gross margin',
            d.sales > 0
                ? '${((d.grossProfit / d.sales) * 100).toStringAsFixed(1)}%'
                : '—',
          ),
          line(
            'Net margin',
            d.sales > 0
                ? '${((d.netProfit / d.sales) * 100).toStringAsFixed(1)}%'
                : '—',
          ),

          pw.SizedBox(height: 20),
          pw.Text('TOP SELLERS',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 12, color: teal)),
          pw.SizedBox(height: 8),
          if (d.topSellers.isEmpty)
            pw.Text('No sales in this period',
                style: pw.TextStyle(color: muted, fontSize: 10))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('Product'),
                    _th('Qty'),
                    _th('Revenue'),
                  ],
                ),
                ...d.topSellers.take(15).map((r) {
                  return pw.TableRow(
                    children: [
                      _td('${r['name']}'),
                      _td('${r['qty']}'),
                      _td(_money.format((r['revenue'] as num?)?.toDouble() ?? 0)),
                    ],
                  );
                }),
              ],
            ),

          pw.SizedBox(height: 24),
          pw.Text(
            'Notes\n'
            '• COGS uses each product’s cost price × quantity sold in the period.\n'
            '• Gross profit = Sales − COGS.\n'
            '• Net profit = Gross profit − Expenses − Cash shortages.\n'
            '• This is a management report, not a full audited statement.',
            style: pw.TextStyle(fontSize: 9, color: muted, height: 1.4),
          ),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _th(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      );

  static pw.Widget _td(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 10)),
      );
}
