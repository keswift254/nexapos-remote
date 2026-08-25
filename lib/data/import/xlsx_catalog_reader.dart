import 'dart:io';
import 'package:excel/excel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'xlsx_catalog_reader.g.dart';

@Riverpod(keepAlive: true)
XlsxCatalogReader xlsxCatalogReader(Ref ref) => const XlsxCatalogReader();

/// Turns a real .xlsx file into the plain grid CatalogImportService
/// expects, keeping that service free of any file-format dependency.
class XlsxCatalogReader {
  const XlsxCatalogReader();

  List<List<String>> read(String path) {
    final bytes = File(path).readAsBytesSync();
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return [];
    final sheet = workbook.tables[workbook.tables.keys.first];
    if (sheet == null) return [];
    return sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();
  }
}
