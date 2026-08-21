import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';
import 'audit_log_storage.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'product_storage.dart';

/// Excel columns (row 1 headers):
/// Name | SKU | Category | Unit | Cost Price | Selling Price | Quantity | Reorder Level | Description | Active
class ProductExcelService {
  static String normalizeUnit(String raw) {
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

  static const headers = [
    'Name',
    'SKU',
    'Category',
    'Unit',
    'Cost Price',
    'Selling Price',
    'Quantity',
    'Reorder Level',
    'Description',
    'Active',
  ];

  static Future<String> exportAll() async {
    final products = await ProductStorage.getAll();
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    // Remove default Sheet1 if present
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        ..value = TextCellValue(headers[c]);
    }

    for (var r = 0; r < products.length; r++) {
      final p = products[r];
      // Prefer current location qty when exporting for shop use
      final qty = LocationService.currentId != null
          ? LocationService.getStockCurrent(p.id)
          : p.quantity;
      final row = [
        p.name,
        p.sku,
        p.category,
        p.unit,
        p.costPrice,
        p.sellingPrice,
        qty,
        p.reorderLevel,
        p.description,
        p.active ? 'YES' : 'NO',
      ];
      for (var c = 0; c < row.length; c++) {
        final v = row[c];
        final cell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        if (v is num) {
          cell.value = DoubleCellValue(v.toDouble());
        } else {
          cell.value = TextCellValue('$v');
        }
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not build Excel file');

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final fileName = 'okikiola_products_$stamp.xlsx';

    if (kIsWeb) {
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          ),
        ],
        subject: 'Okikiola products export',
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Okikiola products export',
        text: 'Product list export from Okikiola Enterprise',
      );
    }

    await AuditLogStorage.log(
      action: 'products_excel_export',
      module: 'products',
      description:
          'Exported ${products.length} products by ${AuthService.currentName}',
    );
    return fileName;
  }

  /// Import result summary.
  static Future<ImportResult> importFromPicker({
    bool updateExistingBySku = true,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }
    final f = result.files.first;
    List<int> bytes;
    if (f.bytes != null) {
      bytes = f.bytes!;
    } else if (f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    } else {
      throw Exception('Could not read file');
    }
    return importBytes(bytes, updateExistingBySku: updateExistingBySku);
  }

  static Future<ImportResult> importBytes(
    List<int> bytes, {
    bool updateExistingBySku = true,
  }) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('Excel has no sheets');
    }
    final sheet = excel.tables.values.first;
    if (sheet.maxRows < 2) {
      throw Exception('Excel is empty or has no data rows');
    }

    // Map header names → column index (case-insensitive)
    final headerRow = sheet.rows.first;
    final col = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final raw = headerRow[i]?.value?.toString().trim().toLowerCase() ?? '';
      if (raw.isEmpty) continue;
      col[raw] = i;
    }

    int colOf(List<String> aliases) {
      for (final a in aliases) {
        if (col.containsKey(a)) return col[a]!;
      }
      return -1;
    }

    final cName = colOf(['name', 'product', 'product name', 'item']);
    final cSku = colOf(['sku', 'code', 'product code', 'barcode']);
    final cCat = colOf(['category', 'cat']);
    final cUnit = colOf(['unit', 'uom']);
    final cCost = colOf(['cost price', 'cost', 'costprice', 'buying price']);
    final cSell = colOf([
      'selling price',
      'sell price',
      'price',
      'sellingprice',
      'retail',
    ]);
    final cQty = colOf(['quantity', 'qty', 'stock', 'opening stock']);
    final cReorder = colOf(['reorder level', 'reorder', 'min stock', 'minimum']);
    final cDesc = colOf(['description', 'note', 'notes']);
    final cActive = colOf(['active', 'status']);

    if (cName < 0) {
      throw Exception('Excel must have a "Name" column');
    }

    final existing = await ProductStorage.getAll();
    final bySku = {
      for (final p in existing)
        if (p.sku.isNotEmpty) p.sku.toUpperCase(): p
    };

    var created = 0;
    var updated = 0;
    var skipped = 0;
    final errors = <String>[];

    String cellStr(List<Data?> row, int c) {
      if (c < 0 || c >= row.length) return '';
      final v = row[c]?.value;
      if (v == null) return '';
      return v.toString().trim();
    }

    double cellNum(List<Data?> row, int c) {
      final s = cellStr(row, c).replaceAll(',', '');
      return double.tryParse(s) ?? 0;
    }

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;
      final name = cellStr(row, cName);
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      try {
        var sku = cellStr(row, cSku);
        if (sku.isEmpty) {
          sku = 'SKU-${name.hashCode.abs()}';
        }
        sku = sku.toUpperCase();
        final category = cellStr(row, cCat);
        final unit = normalizeUnit(cellStr(row, cUnit));
        final cost = cellNum(row, cCost);
        final sell = cellNum(row, cSell);
        final qty = cellNum(row, cQty);
        final reorder = cellNum(row, cReorder);
        final desc = cellStr(row, cDesc);
        final activeRaw = cellStr(row, cActive).toLowerCase();
        final active = activeRaw.isEmpty ||
            activeRaw == 'yes' ||
            activeRaw == 'true' ||
            activeRaw == '1' ||
            activeRaw == 'active';

        final match = bySku[sku];
        if (match != null && updateExistingBySku) {
          final idx = await ProductStorage.indexOfId(match.id);
          if (idx < 0) {
            skipped++;
            continue;
          }
          final updatedP = match.copyWith(
            name: name,
            category: category.isEmpty ? match.category : category,
            unit: unit.isEmpty ? match.unit : unit,
            costPrice: cCost >= 0 ? cost : match.costPrice,
            sellingPrice: cSell >= 0 ? sell : match.sellingPrice,
            quantity: cQty >= 0 ? qty : match.quantity,
            reorderLevel: cReorder >= 0 ? reorder : match.reorderLevel,
            description: cDesc >= 0 ? desc : match.description,
            active: cActive >= 0 ? active : match.active,
            updatedAt: DateTime.now().toIso8601String(),
          );
          await ProductStorage.update(idx, updatedP);
          if (cQty >= 0 && LocationService.currentId != null) {
            await LocationService.setStock(
              LocationService.currentId!,
              match.id,
              qty,
              reason: 'Excel import update',
            );
          }
          updated++;
        } else if (match != null && !updateExistingBySku) {
          skipped++;
        } else {
          final product = await ProductStorage.create(
            name: name,
            sku: sku,
            category: category.isEmpty ? 'General' : category,
            unit: unit.isEmpty ? 'pcs' : unit,
            costPrice: cost,
            sellingPrice: sell,
            quantity: qty,
            reorderLevel: reorder,
            description: desc,
          );
          bySku[sku] = product;
          created++;
        }
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
        if (errors.length > 15) break;
      }
    }

    await AuditLogStorage.log(
      action: 'products_excel_import',
      module: 'products',
      description:
          'Import by ${AuthService.currentName}: +$created new, $updated updated, $skipped skipped',
    );

    return ImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      errors: errors,
    );
  }
}

class ImportResult {
  final int created;
  final int updated;
  final int skipped;
  final List<String> errors;

  ImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  String get summary =>
      'Created $created · Updated $updated · Skipped $skipped'
      '${errors.isEmpty ? '' : ' · ${errors.length} error(s)'}';
}
